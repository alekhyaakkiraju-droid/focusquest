CREATE TABLE subscription_tiers (
    tier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) NOT NULL UNIQUE,
    description TEXT,
    price_cents INTEGER NOT NULL DEFAULT 0,
    billing_interval VARCHAR(16) NOT NULL DEFAULT 'monthly',
    features JSONB NOT NULL DEFAULT '{}',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE premium_content_flags (
    flag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type VARCHAR(64) NOT NULL,
    content_id UUID NOT NULL,
    requires_tier_id UUID REFERENCES subscription_tiers (tier_id) ON DELETE RESTRICT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (content_type, content_id)
);

CREATE INDEX idx_premium_content_flags_content_id ON premium_content_flags (content_id);
CREATE INDEX idx_premium_content_flags_created_at ON premium_content_flags (created_at);
