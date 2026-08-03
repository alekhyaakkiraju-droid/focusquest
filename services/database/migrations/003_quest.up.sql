CREATE TYPE ib_learner_attribute AS ENUM (
    'inquirer',
    'knowledgeable',
    'thinker',
    'communicator',
    'principled',
    'open_minded',
    'caring',
    'risk_taker',
    'balanced',
    'reflective'
);

CREATE TABLE badges (
    badge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(128) NOT NULL,
    description TEXT,
    image_url VARCHAR(512) NOT NULL,
    rarity VARCHAR(32) NOT NULL DEFAULT 'common',
    ib_learner_attribute ib_learner_attribute,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE quests (
    quest_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    xp_reward INTEGER NOT NULL DEFAULT 0,
    coin_reward INTEGER NOT NULL DEFAULT 0,
    badge_id UUID REFERENCES badges (badge_id) ON DELETE RESTRICT,
    required_sessions INTEGER NOT NULL DEFAULT 1,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    level_gate INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_quests_created_at ON quests (created_at);

CREATE TABLE quest_progress (
    progress_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    quest_id UUID NOT NULL REFERENCES quests (quest_id) ON DELETE RESTRICT,
    current_count INTEGER NOT NULL DEFAULT 0,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (child_id, quest_id)
);

CREATE INDEX idx_quest_progress_child_id ON quest_progress (child_id);
CREATE INDEX idx_quest_progress_quest_id ON quest_progress (quest_id);
CREATE INDEX idx_quest_progress_created_at ON quest_progress (created_at);

CREATE TABLE xp_ledger (
    ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    amount INTEGER NOT NULL,
    source VARCHAR(64) NOT NULL,
    reference_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_xp_ledger_child_id ON xp_ledger (child_id);
CREATE INDEX idx_xp_ledger_created_at ON xp_ledger (created_at);

CREATE TABLE streaks (
    streak_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    last_session_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (child_id)
);

CREATE INDEX idx_streaks_child_id ON streaks (child_id);
CREATE INDEX idx_streaks_created_at ON streaks (created_at);
