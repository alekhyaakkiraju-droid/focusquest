package encryption

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync"
	"time"
)

const ciphertextPrefix = "fqenc:v1:"

// DEKRecord stores envelope-wrapped key material for a tenant.
type DEKRecord struct {
	ParentID      string
	TenantKeyID   string
	EncryptedDEK  []byte
	KEKVersion    int
}

// DEKStore persists encrypted data encryption keys per tenant.
type DEKStore interface {
	GetByTenantKeyID(ctx context.Context, tenantKeyID string) (*DEKRecord, error)
	GetByParentID(ctx context.Context, parentID string) (*DEKRecord, error)
	Save(ctx context.Context, record *DEKRecord) error
	UpdateEncryptedDEK(ctx context.Context, tenantKeyID string, encryptedDEK []byte, kekVersion int) error
}

// Service provides application-layer encryption using envelope encryption.
type Service struct {
	kms   KMSClient
	store DEKStore

	mu       sync.RWMutex
	dekCache map[string][]byte
}

func NewService(kms KMSClient, store DEKStore) *Service {
	return &Service{
		kms:      kms,
		store:    store,
		dekCache: make(map[string][]byte),
	}
}

// ProvisionTenantKeys creates a per-tenant Cloud KMS key and stores an envelope-wrapped DEK.
func (s *Service) ProvisionTenantKeys(ctx context.Context, parentID, region string) (string, error) {
	existing, err := s.store.GetByParentID(ctx, parentID)
	if err == nil && existing != nil {
		return existing.TenantKeyID, nil
	}

	tenantKeyID, err := s.kms.CreateTenantKey(ctx, parentID, region)
	if err != nil {
		return "", err
	}

	dek := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, dek); err != nil {
		return "", fmt.Errorf("encryption: generate dek: %w", err)
	}

	encryptedDEK, kekVersion, err := s.kms.EncryptDEK(ctx, tenantKeyID, dek)
	if err != nil {
		return "", err
	}

	record := &DEKRecord{
		ParentID:     parentID,
		TenantKeyID:  tenantKeyID,
		EncryptedDEK: encryptedDEK,
		KEKVersion:   kekVersion,
	}
	if err := s.store.Save(ctx, record); err != nil {
		return "", err
	}

	s.mu.Lock()
	s.dekCache[tenantKeyID] = dek
	s.mu.Unlock()

	return tenantKeyID, nil
}

// Encrypt encrypts plaintext with the tenant's data encryption key using AES-256-GCM.
func (s *Service) Encrypt(ctx context.Context, plaintext, tenantKeyID string) (string, error) {
	if tenantKeyID == "" {
		return "", errors.New("encryption: tenant_key_id is required")
	}

	dek, err := s.loadDEK(ctx, tenantKeyID)
	if err != nil {
		return "", err
	}

	block, err := aes.NewCipher(dek)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := gcm.Seal(nil, nonce, []byte(plaintext), nil)
	payload := append(nonce, ciphertext...)
	return ciphertextPrefix + base64.RawStdEncoding.EncodeToString(payload), nil
}

// Decrypt decrypts ciphertext produced by Encrypt.
func (s *Service) Decrypt(ctx context.Context, ciphertext, tenantKeyID string) (string, error) {
	if tenantKeyID == "" {
		return "", errors.New("encryption: tenant_key_id is required")
	}
	if !strings.HasPrefix(ciphertext, ciphertextPrefix) {
		return "", ErrInvalidCiphertext
	}

	dek, err := s.loadDEK(ctx, tenantKeyID)
	if err != nil {
		return "", err
	}

	raw, err := base64.RawStdEncoding.DecodeString(strings.TrimPrefix(ciphertext, ciphertextPrefix))
	if err != nil {
		return "", ErrInvalidCiphertext
	}

	block, err := aes.NewCipher(dek)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := gcm.NonceSize()
	if len(raw) < nonceSize {
		return "", ErrInvalidCiphertext
	}

	plaintext, err := gcm.Open(nil, raw[:nonceSize], raw[nonceSize:], nil)
	if err != nil {
		return "", ErrInvalidCiphertext
	}
	return string(plaintext), nil
}

// RotateKEK rotates the tenant KEK and re-wraps the DEK without re-encrypting stored child data.
func (s *Service) RotateKEK(ctx context.Context, tenantKeyID string) error {
	record, err := s.store.GetByTenantKeyID(ctx, tenantKeyID)
	if err != nil {
		return err
	}

	dek, err := s.loadDEK(ctx, tenantKeyID)
	if err != nil {
		return err
	}

	if err := s.kms.RotateTenantKey(ctx, tenantKeyID); err != nil {
		return err
	}

	encryptedDEK, kekVersion, err := s.kms.EncryptDEK(ctx, tenantKeyID, dek)
	if err != nil {
		return err
	}

	if err := s.store.UpdateEncryptedDEK(ctx, tenantKeyID, encryptedDEK, kekVersion); err != nil {
		return err
	}

	s.mu.Lock()
	s.dekCache[tenantKeyID] = dek
	s.mu.Unlock()

	_ = record
	return nil
}

func (s *Service) loadDEK(ctx context.Context, tenantKeyID string) ([]byte, error) {
	s.mu.RLock()
	cached, ok := s.dekCache[tenantKeyID]
	s.mu.RUnlock()
	if ok {
		return cached, nil
	}

	record, err := s.store.GetByTenantKeyID(ctx, tenantKeyID)
	if err != nil {
		return nil, err
	}

	dek, err := s.kms.DecryptDEK(ctx, tenantKeyID, record.EncryptedDEK)
	if err != nil {
		return nil, err
	}

	s.mu.Lock()
	s.dekCache[tenantKeyID] = dek
	s.mu.Unlock()
	return dek, nil
}

// EncryptWithLatency wraps Encrypt and returns elapsed time for performance validation.
func (s *Service) EncryptWithLatency(ctx context.Context, plaintext, tenantKeyID string) (string, time.Duration, error) {
	start := time.Now()
	out, err := s.Encrypt(ctx, plaintext, tenantKeyID)
	return out, time.Since(start), err
}
