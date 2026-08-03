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

var ErrQuestProgressNotFound = errors.New("quest progress not found")

type ChildQuestProgress struct {
	ProgressID   uuid.UUID
	ChildID      uuid.UUID
	DisplayName  string
	QuestID      uuid.UUID
	CurrentCount int
	CompletedAt  *time.Time
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type QuestProgressRepo struct {
	db  *sql.DB
	enc *encryption.Service
}

func NewQuestProgressRepo(db *sql.DB, enc *encryption.Service) *QuestProgressRepo {
	return &QuestProgressRepo{db: db, enc: enc}
}

func (r *QuestProgressRepo) GetChildQuestProgress(ctx context.Context, childID, questID uuid.UUID) (*ChildQuestProgress, error) {
	const query = `
		SELECT qp.progress_id, qp.child_id, cp.display_name, qp.quest_id, qp.current_count,
		       qp.completed_at, qp.created_at, qp.updated_at, tek.tenant_key_id
		FROM quest_progress qp
		JOIN child_profiles cp ON cp.child_id = qp.child_id
		JOIN tenant_encryption_keys tek ON tek.parent_id = cp.parent_id
		WHERE qp.child_id = $1 AND qp.quest_id = $2
	`
	row := r.db.QueryRowContext(ctx, query, childID, questID)

	var progress ChildQuestProgress
	var encryptedName, tenantKeyID string
	if err := row.Scan(
		&progress.ProgressID,
		&progress.ChildID,
		&encryptedName,
		&progress.QuestID,
		&progress.CurrentCount,
		&progress.CompletedAt,
		&progress.CreatedAt,
		&progress.UpdatedAt,
		&tenantKeyID,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrQuestProgressNotFound
		}
		return nil, err
	}

	displayName, err := r.enc.Decrypt(ctx, encryptedName, tenantKeyID)
	if err != nil {
		return nil, fmt.Errorf("decrypt display_name: %w", err)
	}
	progress.DisplayName = displayName
	return &progress, nil
}

func (r *QuestProgressRepo) ListByChild(ctx context.Context, childID uuid.UUID) ([]ChildQuestProgress, error) {
	const query = `
		SELECT qp.progress_id, qp.child_id, cp.display_name, qp.quest_id, qp.current_count,
		       qp.completed_at, qp.created_at, qp.updated_at, tek.tenant_key_id
		FROM quest_progress qp
		JOIN child_profiles cp ON cp.child_id = qp.child_id
		JOIN tenant_encryption_keys tek ON tek.parent_id = cp.parent_id
		WHERE qp.child_id = $1
		ORDER BY qp.updated_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, childID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []ChildQuestProgress
	for rows.Next() {
		var progress ChildQuestProgress
		var encryptedName, tenantKeyID string
		if err := rows.Scan(
			&progress.ProgressID,
			&progress.ChildID,
			&encryptedName,
			&progress.QuestID,
			&progress.CurrentCount,
			&progress.CompletedAt,
			&progress.CreatedAt,
			&progress.UpdatedAt,
			&tenantKeyID,
		); err != nil {
			return nil, err
		}

		displayName, err := r.enc.Decrypt(ctx, encryptedName, tenantKeyID)
		if err != nil {
			return nil, fmt.Errorf("decrypt display_name: %w", err)
		}
		progress.DisplayName = displayName
		results = append(results, progress)
	}
	return results, rows.Err()
}
