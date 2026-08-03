package encryption

import (
	"context"
	"sync"
)

// MemoryDEKStore is an in-memory DEKStore for unit tests.
type MemoryDEKStore struct {
	mu      sync.RWMutex
	byKey   map[string]*DEKRecord
	byParent map[string]*DEKRecord
}

func NewMemoryDEKStore() *MemoryDEKStore {
	return &MemoryDEKStore{
		byKey:    make(map[string]*DEKRecord),
		byParent: make(map[string]*DEKRecord),
	}
}

func (m *MemoryDEKStore) GetByTenantKeyID(_ context.Context, tenantKeyID string) (*DEKRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	record, ok := m.byKey[tenantKeyID]
	if !ok {
		return nil, ErrUnknownTenantKey
	}
	return cloneRecord(record), nil
}

func (m *MemoryDEKStore) GetByParentID(_ context.Context, parentID string) (*DEKRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	record, ok := m.byParent[parentID]
	if !ok {
		return nil, ErrUnknownTenantKey
	}
	return cloneRecord(record), nil
}

func (m *MemoryDEKStore) Save(_ context.Context, record *DEKRecord) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	copyRecord := cloneRecord(record)
	m.byKey[record.TenantKeyID] = copyRecord
	m.byParent[record.ParentID] = copyRecord
	return nil
}

func (m *MemoryDEKStore) UpdateEncryptedDEK(_ context.Context, tenantKeyID string, encryptedDEK []byte, kekVersion int) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	record, ok := m.byKey[tenantKeyID]
	if !ok {
		return ErrUnknownTenantKey
	}
	record.EncryptedDEK = append([]byte(nil), encryptedDEK...)
	record.KEKVersion = kekVersion
	return nil
}

func cloneRecord(record *DEKRecord) *DEKRecord {
	return &DEKRecord{
		ParentID:     record.ParentID,
		TenantKeyID:  record.TenantKeyID,
		EncryptedDEK: append([]byte(nil), record.EncryptedDEK...),
		KEKVersion:   record.KEKVersion,
	}
}
