CREATE TYPE focus_session_status AS ENUM ('active', 'completed', 'cancelled', 'abandoned');

CREATE TABLE focus_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_sec INTEGER NOT NULL DEFAULT 0,
    status focus_session_status NOT NULL DEFAULT 'active',
    task_category VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_focus_sessions_child_id ON focus_sessions (child_id);
CREATE INDEX idx_focus_sessions_created_at ON focus_sessions (created_at);

CREATE TYPE break_type AS ENUM ('short', 'long', 'custom');

CREATE TABLE break_records (
    break_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES focus_sessions (session_id) ON DELETE RESTRICT,
    break_type break_type NOT NULL,
    duration_sec INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_break_records_session_id ON break_records (session_id);
CREATE INDEX idx_break_records_created_at ON break_records (created_at);
