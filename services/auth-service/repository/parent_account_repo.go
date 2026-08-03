package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/alekhyaakkiraju-droid/focusquest/packages/shared/encryption"
	"github.com/google/uuid"
)

type ParentAccountRepo struct {
	db  *sql.DB
	kms encryption.KMSClient
}

func NewParentAccountRepo(db *sql.DB, kms encryption.KMSClient) *ParentAccountRepo {
	return &ParentAccountRepo{db: db, kms: kms}
}

// RegisterParent creates a parent account and provisions a per-tenant Cloud KMS key.
func (r *ParentAccountRepo) RegisterParent(ctx context.Context, email, passwordHash, region string) (uuid.UUID, string, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return uuid.Nil, "", err
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback()
		}
	}()

	parentID := uuid.New()
	const insertUser = `
		INSERT INTO users (user_id, email, password_hash, role, region)
		VALUES ($1, $2, $3, 'parent', $4)
	`
	if _, err = tx.ExecContext(ctx, insertUser, parentID, email, passwordHash, region); err != nil {
		return uuid.Nil, "", fmt.Errorf("insert parent user: %w", err)
	}

	svc := encryption.NewService(r.kms, encryption.NewSQLDEKStore(tx))
	tenantKeyID, err := svc.ProvisionTenantKeys(ctx, parentID.String(), region)
	if err != nil {
		return uuid.Nil, "", fmt.Errorf("provision tenant keys: %w", err)
	}

	if err = tx.Commit(); err != nil {
		return uuid.Nil, "", err
	}
	return parentID, tenantKeyID, nil
}

func (r *ParentAccountRepo) EncryptionService() *encryption.Service {
	return encryption.NewService(r.kms, encryption.NewSQLDEKStore(r.db))
}

func (r *ParentAccountRepo) ChildProfiles() *ChildProfileRepo {
	return NewChildProfileRepo(r.db, r.EncryptionService())
}
