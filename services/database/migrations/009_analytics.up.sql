CREATE TABLE daily_summaries (
    summary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    summary_date DATE NOT NULL,
    total_focus_min INTEGER NOT NULL DEFAULT 0,
    session_count INTEGER NOT NULL DEFAULT 0,
    xp_earned INTEGER NOT NULL DEFAULT 0,
    coins_earned INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (child_id, summary_date)
);

CREATE INDEX idx_daily_summaries_child_id ON daily_summaries (child_id);
CREATE INDEX idx_daily_summaries_summary_date ON daily_summaries (summary_date);
CREATE INDEX idx_daily_summaries_created_at ON daily_summaries (created_at);

CREATE TABLE weekly_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES child_profiles (child_id) ON DELETE RESTRICT,
    week_start_date DATE NOT NULL,
    week_end_date DATE NOT NULL,
    total_focus_min INTEGER NOT NULL DEFAULT 0,
    session_count INTEGER NOT NULL DEFAULT 0,
    xp_earned INTEGER NOT NULL DEFAULT 0,
    quests_completed INTEGER NOT NULL DEFAULT 0,
    report_payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (child_id, week_start_date)
);

CREATE INDEX idx_weekly_reports_child_id ON weekly_reports (child_id);
CREATE INDEX idx_weekly_reports_created_at ON weekly_reports (created_at);
