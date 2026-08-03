CREATE TABLE notification_log (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    child_id UUID REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    notification_type VARCHAR(32) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

CREATE INDEX idx_notification_log_user_id ON notification_log (user_id);
CREATE INDEX idx_notification_log_child_id ON notification_log (child_id);
CREATE INDEX idx_notification_log_sent_at ON notification_log (sent_at);

CREATE TABLE device_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    platform VARCHAR(16) NOT NULL,
    token VARCHAR(512) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (platform, token)
);

CREATE INDEX idx_device_tokens_user_id ON device_tokens (user_id);
CREATE INDEX idx_device_tokens_created_at ON device_tokens (created_at);

CREATE TABLE notification_preferences (
    preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    child_id UUID REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    digest_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, child_id)
);

CREATE INDEX idx_notification_preferences_user_id ON notification_preferences (user_id);
CREATE INDEX idx_notification_preferences_child_id ON notification_preferences (child_id);
