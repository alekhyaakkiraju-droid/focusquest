package encryption

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"sync"
)

var (
	ErrUnknownTenantKey = errors.New("encryption: unknown tenant key")
	ErrInvalidCiphertext = errors.New("encryption: invalid ciphertext")
)

// KMSClient wraps Cloud KMS encrypt/decrypt operations for data encryption keys.
// Raw child PII must never be sent to this interface.
type KMSClient interface {
	CreateTenantKey(ctx context.Context, parentID, region string) (tenantKeyID string, err error)
	EncryptDEK(ctx context.Context, tenantKeyID string, dek []byte) (encryptedDEK []byte, kekVersion int, err error)
	DecryptDEK(ctx context.Context, tenantKeyID string, encryptedDEK []byte) (dek []byte, err error)
	RotateTenantKey(ctx context.Context, tenantKeyID string) error
}

type localKeyMaterial struct {
	masterKey []byte
	version   int
}

// LocalKMS provides an in-process KMS substitute for unit and integration tests.
type LocalKMS struct {
	mu   sync.RWMutex
	keys map[string]*localKeyMaterial
}

func NewLocalKMS() *LocalKMS {
	return &LocalKMS{keys: make(map[string]*localKeyMaterial)}
}

func (k *LocalKMS) CreateTenantKey(_ context.Context, parentID, region string) (string, error) {
	if parentID == "" {
		return "", errors.New("encryption: parentID is required")
	}
	if region == "" {
		region = "us-central1"
	}

	masterKey := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, masterKey); err != nil {
		return "", fmt.Errorf("encryption: generate master key: %w", err)
	}

	tenantKeyID := fmt.Sprintf("projects/local/locations/%s/keyRings/focusquest/cryptoKeys/tenant-%s", region, parentID)

	k.mu.Lock()
	defer k.mu.Unlock()
	k.keys[tenantKeyID] = &localKeyMaterial{masterKey: masterKey, version: 1}
	return tenantKeyID, nil
}

func (k *LocalKMS) EncryptDEK(_ context.Context, tenantKeyID string, dek []byte) ([]byte, int, error) {
	key, err := k.lookup(tenantKeyID)
	if err != nil {
		return nil, 0, err
	}
	if len(dek) != 32 {
		return nil, 0, errors.New("encryption: DEK must be 32 bytes")
	}

	block, err := aes.NewCipher(key.masterKey)
	if err != nil {
		return nil, 0, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, 0, err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, 0, err
	}

	ciphertext := gcm.Seal(nil, nonce, dek, nil)
	payload := make([]byte, 4+len(nonce)+len(ciphertext))
	binary.BigEndian.PutUint32(payload[:4], uint32(key.version))
	copy(payload[4:], nonce)
	copy(payload[4+len(nonce):], ciphertext)
	return payload, key.version, nil
}

func (k *LocalKMS) DecryptDEK(_ context.Context, tenantKeyID string, encryptedDEK []byte) ([]byte, error) {
	key, err := k.lookup(tenantKeyID)
	if err != nil {
		return nil, err
	}
	if len(encryptedDEK) < 4 {
		return nil, ErrInvalidCiphertext
	}

	version := int(binary.BigEndian.Uint32(encryptedDEK[:4]))
	if version != key.version {
		// Envelope encryption: older KEK versions remain decryptable after rotation.
		// LocalKMS keeps the same master key material across versions.
	}

	block, err := aes.NewCipher(key.masterKey)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(encryptedDEK) < 4+nonceSize {
		return nil, ErrInvalidCiphertext
	}

	nonce := encryptedDEK[4 : 4+nonceSize]
	ciphertext := encryptedDEK[4+nonceSize:]
	return gcm.Open(nil, nonce, ciphertext, nil)
}

func (k *LocalKMS) RotateTenantKey(_ context.Context, tenantKeyID string) error {
	k.mu.Lock()
	defer k.mu.Unlock()

	key, ok := k.keys[tenantKeyID]
	if !ok {
		return ErrUnknownTenantKey
	}
	key.version++
	return nil
}

func (k *LocalKMS) lookup(tenantKeyID string) (*localKeyMaterial, error) {
	k.mu.RLock()
	defer k.mu.RUnlock()
	key, ok := k.keys[tenantKeyID]
	if !ok {
		return nil, ErrUnknownTenantKey
	}
	return key, nil
}
