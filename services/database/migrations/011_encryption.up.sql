CREATE TABLE tenant_encryption_keys (
    parent_id UUID PRIMARY KEY REFERENCES users (user_id) ON DELETE RESTRICT,
    tenant_key_id VARCHAR(512) NOT NULL UNIQUE,
    encrypted_dek BYTEA NOT NULL,
    kek_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tenant_encryption_keys_tenant_key_id ON tenant_encryption_keys (tenant_key_id);
CREATE INDEX idx_tenant_encryption_keys_created_at ON tenant_encryption_keys (created_at);

COMMENT ON TABLE tenant_encryption_keys IS 'Envelope-wrapped per-tenant DEKs; KEK material lives in Cloud KMS (WO-005)';
