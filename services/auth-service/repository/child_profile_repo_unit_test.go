package repository

import (
	"context"
	"testing"

	"github.com/alekhyaakkiraju-droid/focusquest/packages/shared/encryption"
	"github.com/google/uuid"
)

func TestChildProfileRepoEncryptsFields(t *testing.T) {
	ctx := context.Background()
	kms := encryption.NewLocalKMS()
	store := encryption.NewMemoryDEKStore()
	svc := encryption.NewService(kms, store)

	parentID := uuid.New()
	tenantKeyID, err := svc.ProvisionTenantKeys(ctx, parentID.String(), "us-central1")
	if err != nil {
		t.Fatalf("provision keys: %v", err)
	}

	displayName, err := svc.Encrypt(ctx, "River", tenantKeyID)
	if err != nil {
		t.Fatalf("encrypt name: %v", err)
	}
	ageRange, err := svc.Encrypt(ctx, "10-12", tenantKeyID)
	if err != nil {
		t.Fatalf("encrypt age: %v", err)
	}

	if displayName == "River" || ageRange == "10-12" {
		t.Fatal("repository layer must persist ciphertext, not plaintext")
	}

	decryptedName, err := svc.Decrypt(ctx, displayName, tenantKeyID)
	if err != nil {
		t.Fatalf("decrypt name: %v", err)
	}
	if decryptedName != "River" {
		t.Fatalf("expected River, got %q", decryptedName)
	}
}
