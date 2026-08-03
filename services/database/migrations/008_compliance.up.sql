CREATE TABLE consent_records (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    consent_type VARCHAR(64) NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    consent_hash VARCHAR(128) NOT NULL,
    consent_payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_consent_records_parent_id ON consent_records (parent_id);
CREATE INDEX idx_consent_records_child_id ON consent_records (child_id);
CREATE INDEX idx_consent_records_created_at ON consent_records (created_at);

CREATE TYPE data_deletion_status AS ENUM ('pending', 'in_progress', 'fulfilled', 'rejected');

CREATE TABLE data_deletion_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    child_id UUID REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    status data_deletion_status NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fulfilled_at TIMESTAMPTZ,
    notes TEXT
);

CREATE INDEX idx_data_deletion_requests_user_id ON data_deletion_requests (user_id);
CREATE INDEX idx_data_deletion_requests_child_id ON data_deletion_requests (child_id);
CREATE INDEX idx_data_deletion_requests_requested_at ON data_deletion_requests (requested_at);

CREATE TABLE audit_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES users (user_id) ON DELETE RESTRICT,
    action VARCHAR(128) NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id UUID,
    details JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_actor_id ON audit_log (actor_id);
CREATE INDEX idx_audit_log_created_at ON audit_log (created_at);
