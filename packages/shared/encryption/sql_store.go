package encryption

import (
	"context"
	"database/sql"
	"errors"
)

type sqlQuerier interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// SQLDEKStore persists tenant encryption keys in PostgreSQL.
type SQLDEKStore struct {
	db sqlQuerier
}

func NewSQLDEKStore(db sqlQuerier) *SQLDEKStore {
	return &SQLDEKStore{db: db}
}

func (s *SQLDEKStore) GetByTenantKeyID(ctx context.Context, tenantKeyID string) (*DEKRecord, error) {
	const query = `
		SELECT parent_id, tenant_key_id, encrypted_dek, kek_version
		FROM tenant_encryption_keys
		WHERE tenant_key_id = $1
	`
	return s.scanOne(ctx, query, tenantKeyID)
}

func (s *SQLDEKStore) GetByParentID(ctx context.Context, parentID string) (*DEKRecord, error) {
	const query = `
		SELECT parent_id, tenant_key_id, encrypted_dek, kek_version
		FROM tenant_encryption_keys
		WHERE parent_id = $1
	`
	return s.scanOne(ctx, query, parentID)
}

func (s *SQLDEKStore) Save(ctx context.Context, record *DEKRecord) error {
	const query = `
		INSERT INTO tenant_encryption_keys (parent_id, tenant_key_id, encrypted_dek, kek_version)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (parent_id) DO UPDATE
		SET tenant_key_id = EXCLUDED.tenant_key_id,
		    encrypted_dek = EXCLUDED.encrypted_dek,
		    kek_version = EXCLUDED.kek_version,
		    updated_at = NOW()
	`
	_, err := s.db.ExecContext(ctx, query, record.ParentID, record.TenantKeyID, record.EncryptedDEK, record.KEKVersion)
	return err
}

func (s *SQLDEKStore) UpdateEncryptedDEK(ctx context.Context, tenantKeyID string, encryptedDEK []byte, kekVersion int) error {
	const query = `
		UPDATE tenant_encryption_keys
		SET encrypted_dek = $2,
		    kek_version = $3,
		    updated_at = NOW()
		WHERE tenant_key_id = $1
	`
	result, err := s.db.ExecContext(ctx, query, tenantKeyID, encryptedDEK, kekVersion)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrUnknownTenantKey
	}
	return nil
}

func (s *SQLDEKStore) scanOne(ctx context.Context, query string, arg string) (*DEKRecord, error) {
	row := s.db.QueryRowContext(ctx, query, arg)
	record := &DEKRecord{}
	if err := row.Scan(&record.ParentID, &record.TenantKeyID, &record.EncryptedDEK, &record.KEKVersion); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUnknownTenantKey
		}
		return nil, err
	}
	return record, nil
}
