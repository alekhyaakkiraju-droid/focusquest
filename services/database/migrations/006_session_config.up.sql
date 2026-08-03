CREATE TABLE child_session_config (
    config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    min_duration_sec INTEGER NOT NULL DEFAULT 300 CHECK (min_duration_sec >= 60),
    max_duration_sec INTEGER NOT NULL DEFAULT 900 CHECK (max_duration_sec >= min_duration_sec),
    daily_cap_minutes INTEGER NOT NULL DEFAULT 120 CHECK (daily_cap_minutes > 0),
    notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (child_id)
);

CREATE INDEX idx_child_session_config_child_id ON child_session_config (child_id);
