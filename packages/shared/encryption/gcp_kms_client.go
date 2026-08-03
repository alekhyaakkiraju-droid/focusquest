package encryption

import (
	"context"
	"errors"
	"fmt"
	"strings"

	kms "cloud.google.com/go/kms/apiv1"
	"cloud.google.com/go/kms/apiv1/kmspb"
	"github.com/google/uuid"
	"google.golang.org/api/option"
	"google.golang.org/protobuf/types/known/durationpb"
)

// GCPKMS provisions per-tenant keys in Cloud KMS for production deployments.
type GCPKMS struct {
	client    *kms.KeyManagementClient
	projectID string
	keyRing   string
}

type GCPKMSConfig struct {
	ProjectID string
	Location  string
	KeyRing   string
}

func NewGCPKMS(ctx context.Context, cfg GCPKMSConfig, opts ...option.ClientOption) (*GCPKMS, error) {
	if cfg.ProjectID == "" || cfg.Location == "" || cfg.KeyRing == "" {
		return nil, errors.New("encryption: GCP KMS project, location, and key ring are required")
	}

	client, err := kms.NewKeyManagementClient(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("encryption: create kms client: %w", err)
	}

	return &GCPKMS{
		client:    client,
		projectID: cfg.ProjectID,
		keyRing:   fmt.Sprintf("projects/%s/locations/%s/keyRings/%s", cfg.ProjectID, cfg.Location, cfg.KeyRing),
	}, nil
}

func (g *GCPKMS) Close() error {
	return g.client.Close()
}

func (g *GCPKMS) CreateTenantKey(ctx context.Context, parentID, region string) (string, error) {
	if parentID == "" {
		return "", errors.New("encryption: parentID is required")
	}
	if region == "" {
		region = "us-central1"
	}

	keyID := fmt.Sprintf("tenant-%s-%s", parentID, strings.ReplaceAll(uuid.NewString(), "-", ""))

	req := &kmspb.CreateCryptoKeyRequest{
		Parent:      g.keyRing,
		CryptoKeyId: keyID,
		CryptoKey: &kmspb.CryptoKey{
			Purpose: kmspb.CryptoKey_ENCRYPT_DECRYPT,
			VersionTemplate: &kmspb.CryptoKeyVersionTemplate{
				Algorithm:       kmspb.CryptoKeyVersion_GOOGLE_SYMMETRIC_ENCRYPTION,
				ProtectionLevel: kmspb.ProtectionLevel_SOFTWARE,
			},
			RotationSchedule: &kmspb.CryptoKey_RotationPeriod{
				RotationPeriod: durationpb.New(7776000),
			},
		},
	}

	key, err := g.client.CreateCryptoKey(ctx, req)
	if err != nil {
		return "", fmt.Errorf("encryption: create tenant crypto key: %w", err)
	}
	return key.Name, nil
}

func (g *GCPKMS) EncryptDEK(ctx context.Context, tenantKeyID string, dek []byte) ([]byte, int, error) {
	resp, err := g.client.Encrypt(ctx, &kmspb.EncryptRequest{
		Name:      tenantKeyID,
		Plaintext: dek,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("encryption: kms encrypt dek: %w", err)
	}

	version := 1
	if resp.Name != "" {
		parts := strings.Split(resp.Name, "/")
		if len(parts) > 0 {
			versionPart := parts[len(parts)-1]
			if strings.HasPrefix(versionPart, "cryptoKeyVersions/") {
				fmt.Sscanf(versionPart, "cryptoKeyVersions/%d", &version)
			}
		}
	}

	return resp.Ciphertext, version, nil
}

func (g *GCPKMS) DecryptDEK(ctx context.Context, tenantKeyID string, encryptedDEK []byte) ([]byte, error) {
	resp, err := g.client.Decrypt(ctx, &kmspb.DecryptRequest{
		Name:       tenantKeyID,
		Ciphertext: encryptedDEK,
	})
	if err != nil {
		return nil, fmt.Errorf("encryption: kms decrypt dek: %w", err)
	}
	return resp.Plaintext, nil
}

func (g *GCPKMS) RotateTenantKey(ctx context.Context, tenantKeyID string) error {
	_, err := g.client.CreateCryptoKeyVersion(ctx, &kmspb.CreateCryptoKeyVersionRequest{
		Parent: tenantKeyID,
	})
	if err != nil {
		return fmt.Errorf("encryption: rotate tenant key: %w", err)
	}
	return nil
}
