package encryption

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestEncryptDecryptRoundTrip(t *testing.T) {
	ctx := context.Background()
	kms := NewLocalKMS()
	store := NewMemoryDEKStore()
	svc := NewService(kms, store)

	parentID := "11111111-1111-1111-1111-111111111111"
	tenantKeyID, err := svc.ProvisionTenantKeys(ctx, parentID, "us-central1")
	if err != nil {
		t.Fatalf("provision tenant keys: %v", err)
	}

	plaintext := "Ava"
	ciphertext, err := svc.Encrypt(ctx, plaintext, tenantKeyID)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	if ciphertext == plaintext {
		t.Fatal("expected ciphertext to differ from plaintext")
	}
	if !strings.HasPrefix(ciphertext, ciphertextPrefix) {
		t.Fatalf("expected ciphertext prefix, got %q", ciphertext)
	}

	decrypted, err := svc.Decrypt(ctx, ciphertext, tenantKeyID)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}
	if decrypted != plaintext {
		t.Fatalf("expected %q, got %q", plaintext, decrypted)
	}
}

func TestKeyRotationPreservesExistingCiphertext(t *testing.T) {
	ctx := context.Background()
	kms := NewLocalKMS()
	store := NewMemoryDEKStore()
	svc := NewService(kms, store)

	parentID := "22222222-2222-2222-2222-222222222222"
	tenantKeyID, err := svc.ProvisionTenantKeys(ctx, parentID, "us-central1")
	if err != nil {
		t.Fatalf("provision tenant keys: %v", err)
	}

	ciphertext, err := svc.Encrypt(ctx, "7-9", tenantKeyID)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}

	if err := svc.RotateKEK(ctx, tenantKeyID); err != nil {
		t.Fatalf("rotate kek: %v", err)
	}

	decrypted, err := svc.Decrypt(ctx, ciphertext, tenantKeyID)
	if err != nil {
		t.Fatalf("decrypt after rotation: %v", err)
	}
	if decrypted != "7-9" {
		t.Fatalf("expected decrypted age range 7-9, got %q", decrypted)
	}
}

func TestEncryptPerformanceUnder10ms(t *testing.T) {
	ctx := context.Background()
	kms := NewLocalKMS()
	store := NewMemoryDEKStore()
	svc := NewService(kms, store)

	parentID := "33333333-3333-3333-3333-333333333333"
	tenantKeyID, err := svc.ProvisionTenantKeys(ctx, parentID, "us-central1")
	if err != nil {
		t.Fatalf("provision tenant keys: %v", err)
	}

	_, warmupErr := svc.Encrypt(ctx, "warmup", tenantKeyID)
	if warmupErr != nil {
		t.Fatalf("warmup encrypt: %v", warmupErr)
	}

	const iterations = 100
	var total time.Duration
	for i := 0; i < iterations; i++ {
		_, elapsed, err := svc.EncryptWithLatency(ctx, "Child Name", tenantKeyID)
		if err != nil {
			t.Fatalf("encrypt iteration %d: %v", i, err)
		}
		total += elapsed
	}

	avg := total / iterations
	if avg > 10*time.Millisecond {
		t.Fatalf("average encrypt latency %v exceeds 10ms budget", avg)
	}
}

func TestTenantIsolation(t *testing.T) {
	ctx := context.Background()
	kms := NewLocalKMS()
	store := NewMemoryDEKStore()
	svc := NewService(kms, store)

	tenantA, err := svc.ProvisionTenantKeys(ctx, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "us-central1")
	if err != nil {
		t.Fatalf("provision tenant A: %v", err)
	}
	tenantB, err := svc.ProvisionTenantKeys(ctx, "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "us-central1")
	if err != nil {
		t.Fatalf("provision tenant B: %v", err)
	}

	ciphertext, err := svc.Encrypt(ctx, "secret", tenantA)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}

	if _, err := svc.Decrypt(ctx, ciphertext, tenantB); err == nil {
		t.Fatal("expected decrypt with wrong tenant key to fail")
	}
}
