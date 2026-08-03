#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATIONS_DIR="$ROOT/services/database/migrations"

failures=0

assert_migration_contains() {
  local pattern="$1"
  local message="$2"
  if ! grep -R -q --include='*.up.sql' "$pattern" "$MIGRATIONS_DIR"; then
    echo "FAIL: $message"
    failures=$((failures + 1))
  else
    echo "PASS: $message"
  fi
}

assert_migration_not_contains() {
  local pattern="$1"
  local message="$2"
  if grep -R -q --include='*.up.sql' "$pattern" "$MIGRATIONS_DIR"; then
    echo "FAIL: $message"
    failures=$((failures + 1))
  else
    echo "PASS: $message"
  fi
}

required_tables=(
  users
  child_profiles
  refresh_tokens
  oauth_links
  focus_sessions
  break_records
  quests
  quest_progress
  xp_ledger
  badges
  streaks
  ib_pyp_themes
  ib_subject_areas
  teks_standards
  quest_curriculum_tags
  coin_ledger
  avatar_items
  avatar_purchases
  child_session_config
  notification_log
  device_tokens
  notification_preferences
  consent_records
  data_deletion_requests
  audit_log
  daily_summaries
  weekly_reports
  subscription_tiers
  premium_content_flags
)

for table in "${required_tables[@]}"; do
  assert_migration_contains "CREATE TABLE ${table}" "Migration defines table '${table}'"
done

assert_migration_contains "CREATE EXTENSION IF NOT EXISTS pgcrypto" "pgcrypto extension migration present"
assert_migration_contains "gen_random_uuid()" "UUID defaults use gen_random_uuid()"
assert_migration_contains "CREATE TYPE ib_learner_attribute AS ENUM" "IB learner attribute enum defined"
assert_migration_contains "'inquirer'" "IB enum includes inquirer"
assert_migration_contains "'reflective'" "IB enum includes reflective"
assert_migration_contains "enforce_max_children_per_parent" "Max-5-children trigger function defined"
assert_migration_contains "consent_hash" "Consent records include tamper-evident consent_hash"
assert_migration_contains "DEFAULT 300" "Session config min_duration_sec default 300"
assert_migration_contains "DEFAULT 900" "Session config max_duration_sec default 900"
assert_migration_contains "DEFAULT 120" "Session config daily_cap_minutes default 120"

child_fk_files=(
  002_timer.up.sql
  003_quest.up.sql
  005_coin_economy.up.sql
  006_session_config.up.sql
  007_notification.up.sql
  008_compliance.up.sql
  009_analytics.up.sql
)

for file in "${child_fk_files[@]}"; do
  if grep -q "REFERENCES child_profiles" "$MIGRATIONS_DIR/$file" \
    && ! grep -q "ON DELETE RESTRICT" "$MIGRATIONS_DIR/$file"; then
    echo "FAIL: $file references child_profiles without ON DELETE RESTRICT"
    failures=$((failures + 1))
  else
    echo "PASS: $file child FK constraints use RESTRICT or no child FK"
  fi
done

assert_migration_not_contains "ON DELETE CASCADE" "No ON DELETE CASCADE in up migrations"

up_count="$(find "$MIGRATIONS_DIR" -name '*.up.sql' | wc -l | tr -d ' ')"
down_count="$(find "$MIGRATIONS_DIR" -name '*.down.sql' | wc -l | tr -d ' ')"
if [[ "$up_count" != "$down_count" ]]; then
  echo "FAIL: up/down migration count mismatch ($up_count up, $down_count down)"
  failures=$((failures + 1))
else
  echo "PASS: matching up/down migration file counts ($up_count)"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "$failures schema configuration test(s) failed"
  exit 1
fi

echo "All schema configuration contract tests passed"
