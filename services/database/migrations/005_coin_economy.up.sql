CREATE TABLE coin_ledger (
    ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL,
    source VARCHAR(64) NOT NULL,
    reference_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_coin_ledger_child_id ON coin_ledger (child_id);
CREATE INDEX idx_coin_ledger_created_at ON coin_ledger (created_at);

CREATE TABLE avatar_items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(128) NOT NULL,
    image_url VARCHAR(512) NOT NULL,
    cost INTEGER NOT NULL DEFAULT 0,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE avatar_purchases (
    purchase_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    item_id UUID NOT NULL REFERENCES avatar_items (item_id) ON DELETE RESTRICT,
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (child_id, item_id)
);

CREATE INDEX idx_avatar_purchases_child_id ON avatar_purchases (child_id);
CREATE INDEX idx_avatar_purchases_purchased_at ON avatar_purchases (purchased_at);
