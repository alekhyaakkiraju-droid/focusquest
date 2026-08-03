CREATE TABLE ib_pyp_themes (
    theme_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(128) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE ib_subject_areas (
    subject_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(128) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE teks_standards (
    teks_standard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    standard_code VARCHAR(32) NOT NULL UNIQUE,
    grade_level VARCHAR(16) NOT NULL,
    subject VARCHAR(64) NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE quest_curriculum_tags (
    tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quest_id UUID NOT NULL REFERENCES quests (quest_id) ON DELETE RESTRICT,
    theme_id UUID REFERENCES ib_pyp_themes (theme_id) ON DELETE RESTRICT,
    subject_id UUID REFERENCES ib_subject_areas (subject_id) ON DELETE RESTRICT,
    teks_standard_id UUID REFERENCES teks_standards (teks_standard_id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT quest_curriculum_tag_has_reference CHECK (
        theme_id IS NOT NULL
        OR subject_id IS NOT NULL
        OR teks_standard_id IS NOT NULL
    )
);

CREATE INDEX idx_quest_curriculum_tags_quest_id ON quest_curriculum_tags (quest_id);
CREATE INDEX idx_quest_curriculum_tags_created_at ON quest_curriculum_tags (created_at);
