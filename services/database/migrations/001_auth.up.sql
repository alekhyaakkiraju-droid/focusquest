CREATE TYPE user_role AS ENUM ('parent', 'child', 'teacher', 'admin');

CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'parent',
    region VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_created_at ON users (created_at);

CREATE TABLE child_profiles (
    child_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    display_name VARCHAR(255) NOT NULL,
    age_range VARCHAR(32) NOT NULL,
    pin_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN child_profiles.display_name IS 'WO-005: encrypt at application layer before persistence';
COMMENT ON COLUMN child_profiles.age_range IS 'WO-005: encrypt at application layer before persistence';

CREATE INDEX idx_child_profiles_parent_id ON child_profiles (parent_id);
CREATE INDEX idx_child_profiles_created_at ON child_profiles (created_at);

CREATE OR REPLACE FUNCTION enforce_max_children_per_parent()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.parent_id IS NOT DISTINCT FROM OLD.parent_id THEN
        RETURN NEW;
    END IF;

    IF (
        SELECT COUNT(*)
        FROM child_profiles
        WHERE parent_id = NEW.parent_id
          AND child_id IS DISTINCT FROM NEW.child_id
    ) >= 5 THEN
        RAISE EXCEPTION 'Parent % already has the maximum of 5 child profiles', NEW.parent_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_max_children_per_parent
    BEFORE INSERT OR UPDATE OF parent_id ON child_profiles
    FOR EACH ROW
    EXECUTE FUNCTION enforce_max_children_per_parent();

CREATE TABLE refresh_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_created_at ON refresh_tokens (created_at);

CREATE TABLE oauth_links (
    oauth_link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    provider VARCHAR(32) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_user_id)
);

CREATE INDEX idx_oauth_links_user_id ON oauth_links (user_id);
CREATE INDEX idx_oauth_links_created_at ON oauth_links (created_at);
