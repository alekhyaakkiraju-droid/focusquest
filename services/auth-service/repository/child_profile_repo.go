package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/alekhyaakkiraju-droid/focusquest/packages/shared/encryption"
	"github.com/google/uuid"
)

var ErrChildProfileNotFound = errors.New("child profile not found")

type ChildProfile struct {
	ChildID     uuid.UUID
	ParentID    uuid.UUID
	DisplayName string
	AgeRange    string
	PINHash     string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type ChildProfileRepo struct {
	db  *sql.DB
	enc *encryption.Service
}

func NewChildProfileRepo(db *sql.DB, enc *encryption.Service) *ChildProfileRepo {
	return &ChildProfileRepo{db: db, enc: enc}
}

func (r *ChildProfileRepo) CreateProfile(ctx context.Context, parentID uuid.UUID, displayName, ageRange, pinHash string) (*ChildProfile, error) {
	profile := &ChildProfile{
		ParentID:    parentID,
		DisplayName: displayName,
		AgeRange:    ageRange,
		PINHash:     pinHash,
	}
	if err := r.Create(ctx, profile); err != nil {
		return nil, err
	}
	return profile, nil
}

func (r *ChildProfileRepo) Create(ctx context.Context, profile *ChildProfile) error {
	record, err := r.encStoreRecord(ctx, profile.ParentID)
	if err != nil {
		return err
	}

	encryptedName, err := r.enc.Encrypt(ctx, profile.DisplayName, record.TenantKeyID)
	if err != nil {
		return fmt.Errorf("encrypt display_name: %w", err)
	}
	encryptedAge, err := r.enc.Encrypt(ctx, profile.AgeRange, record.TenantKeyID)
	if err != nil {
		return fmt.Errorf("encrypt age_range: %w", err)
	}

	const query = `
		INSERT INTO child_profiles (child_id, parent_id, display_name, age_range, pin_hash)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING created_at, updated_at
	`
	if profile.ChildID == uuid.Nil {
		profile.ChildID = uuid.New()
	}

	row := r.db.QueryRowContext(
		ctx,
		query,
		profile.ChildID,
		profile.ParentID,
		encryptedName,
		encryptedAge,
		profile.PINHash,
	)
	return row.Scan(&profile.CreatedAt, &profile.UpdatedAt)
}

func (r *ChildProfileRepo) GetByID(ctx context.Context, childID uuid.UUID) (*ChildProfile, error) {
	const query = `
		SELECT cp.child_id, cp.parent_id, cp.display_name, cp.age_range, cp.pin_hash, cp.created_at, cp.updated_at,
		       tek.tenant_key_id
		FROM child_profiles cp
		JOIN tenant_encryption_keys tek ON tek.parent_id = cp.parent_id
		WHERE cp.child_id = $1
	`
	row := r.db.QueryRowContext(ctx, query, childID)

	var profile ChildProfile
	var encryptedName, encryptedAge, tenantKeyID string
	if err := row.Scan(
		&profile.ChildID,
		&profile.ParentID,
		&encryptedName,
		&encryptedAge,
		&profile.PINHash,
		&profile.CreatedAt,
		&profile.UpdatedAt,
		&tenantKeyID,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrChildProfileNotFound
		}
		return nil, err
	}

	displayName, err := r.enc.Decrypt(ctx, encryptedName, tenantKeyID)
	if err != nil {
		return nil, fmt.Errorf("decrypt display_name: %w", err)
	}
	ageRange, err := r.enc.Decrypt(ctx, encryptedAge, tenantKeyID)
	if err != nil {
		return nil, fmt.Errorf("decrypt age_range: %w", err)
	}

	profile.DisplayName = displayName
	profile.AgeRange = ageRange
	return &profile, nil
}

func (r *ChildProfileRepo) ListByParent(ctx context.Context, parentID uuid.UUID) ([]ChildProfile, error) {
	const query = `
		SELECT cp.child_id, cp.parent_id, cp.display_name, cp.age_range, cp.pin_hash, cp.created_at, cp.updated_at,
		       tek.tenant_key_id
		FROM child_profiles cp
		JOIN tenant_encryption_keys tek ON tek.parent_id = cp.parent_id
		WHERE cp.parent_id = $1
		ORDER BY cp.created_at ASC
	`
	rows, err := r.db.QueryContext(ctx, query, parentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var profiles []ChildProfile
	for rows.Next() {
		var profile ChildProfile
		var encryptedName, encryptedAge, tenantKeyID string
		if err := rows.Scan(
			&profile.ChildID,
			&profile.ParentID,
			&encryptedName,
			&encryptedAge,
			&profile.PINHash,
			&profile.CreatedAt,
			&profile.UpdatedAt,
			&tenantKeyID,
		); err != nil {
			return nil, err
		}

		displayName, err := r.enc.Decrypt(ctx, encryptedName, tenantKeyID)
		if err != nil {
			return nil, fmt.Errorf("decrypt display_name: %w", err)
		}
		ageRange, err := r.enc.Decrypt(ctx, encryptedAge, tenantKeyID)
		if err != nil {
			return nil, fmt.Errorf("decrypt age_range: %w", err)
		}

		profile.DisplayName = displayName
		profile.AgeRange = ageRange
		profiles = append(profiles, profile)
	}
	return profiles, rows.Err()
}

func (r *ChildProfileRepo) encStoreRecord(ctx context.Context, parentID uuid.UUID) (*encryption.DEKRecord, error) {
	store := encryption.NewSQLDEKStore(r.db)
	record, err := store.GetByParentID(ctx, parentID.String())
	if err != nil {
		return nil, fmt.Errorf("load tenant encryption key for parent %s: %w", parentID, err)
	}
	return record, nil
}
