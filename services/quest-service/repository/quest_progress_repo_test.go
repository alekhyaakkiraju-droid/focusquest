package repository

import (
	"context"
	"testing"

	"github.com/alekhyaakkiraju-droid/focusquest/packages/shared/encryption"
)

func TestQuestProgressRepoDecryptsDisplayName(t *testing.T) {
	ctx := context.Background()
	kms := encryption.NewLocalKMS()
	store := encryption.NewMemoryDEKStore()
	svc := encryption.NewService(kms, store)

	parentID := "44444444-4444-4444-4444-444444444444"
	tenantKeyID, err := svc.ProvisionTenantKeys(ctx, parentID, "us-central1")
	if err != nil {
		t.Fatalf("provision keys: %v", err)
	}

	ciphertext, err := svc.Encrypt(ctx, "Leo", tenantKeyID)
	if err != nil {
		t.Fatalf("encrypt display name: %v", err)
	}

	plaintext, err := svc.Decrypt(ctx, ciphertext, tenantKeyID)
	if err != nil {
		t.Fatalf("decrypt display name: %v", err)
	}
	if plaintext != "Leo" {
		t.Fatalf("expected Leo, got %q", plaintext)
	}
}
