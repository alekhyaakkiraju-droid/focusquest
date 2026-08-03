#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONTAINER_NAME="focusquest-schema-test"
POSTGRES_USER="focusquest"
POSTGRES_PASSWORD="focusquest"
POSTGRES_DB="focusquest"
POSTGRES_PORT="${POSTGRES_PORT:-54329}"
DATABASE_URL="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$POSTGRES_PORT/$POSTGRES_DB?sslmode=disable"

REQUIRED_TABLES=(
  users
  child_profiles
  tenant_encryption_keys
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

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: Docker not available; schema integration test skipped"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon not running; schema integration test skipped"
  exit 0
fi

echo "Starting Postgres test container..."
cleanup
docker run -d \
  --name "$CONTAINER_NAME" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -p "$POSTGRES_PORT:5432" \
  postgres:16-alpine >/dev/null

echo "Waiting for Postgres..."
for _ in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
  echo "FAIL: Postgres did not become ready"
  exit 1
fi

echo "Resolving migrate CLI..."
MIGRATE_BIN=""
if command -v migrate >/dev/null 2>&1; then
  MIGRATE_BIN="$(command -v migrate)"
elif command -v go >/dev/null 2>&1; then
  go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@v4.18.1
  MIGRATE_BIN="$(command -v migrate || echo "${GOPATH:-$HOME/go}/bin/migrate")"
fi

run_migrate() {
  if [[ -n "$MIGRATE_BIN" && -x "$MIGRATE_BIN" ]]; then
    "$MIGRATE_BIN" -path "$ROOT/migrations" -database "$DATABASE_URL" "$@"
    return
  fi

  docker run --rm \
    -v "$ROOT/migrations:/migrations" \
    migrate/migrate:v4.18.1 \
    -path=/migrations \
    -database "$DATABASE_URL" \
    "$@"
}

migrate_version() {
  if [[ -n "$MIGRATE_BIN" && -x "$MIGRATE_BIN" ]]; then
    "$MIGRATE_BIN" -path "$ROOT/migrations" -database "$DATABASE_URL" version 2>&1 | awk '{print $1}'
    return
  fi

  docker run --rm \
    -v "$ROOT/migrations:/migrations" \
    migrate/migrate:v4.18.1 \
    -path=/migrations \
    -database "$DATABASE_URL" \
    version 2>&1 | awk '{print $1}'
}

if [[ "$OSTYPE" == darwin* ]]; then
  DATABASE_URL="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@host.docker.internal:$POSTGRES_PORT/$POSTGRES_DB?sslmode=disable"
fi

echo "Applying migrations (first run)..."
run_migrate up

echo "Applying migrations (second run — idempotency check)..."
if ! run_migrate up; then
  echo "FAIL: second migrate up failed"
  exit 1
fi

version="$(migrate_version)"
if [[ "$version" != "11" ]]; then
  echo "FAIL: expected migration version 11, got '$version'"
  exit 1
fi

echo "Verifying required tables exist..."
missing=0
for table in "${REQUIRED_TABLES[@]}"; do
  exists="$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
    "SELECT to_regclass('public.$table') IS NOT NULL;")"
  if [[ "$exists" != "t" ]]; then
    echo "FAIL: missing table '$table'"
    missing=$((missing + 1))
  else
    echo "PASS: table '$table' exists"
  fi
done

if [[ "$missing" -gt 0 ]]; then
  echo "$missing required table(s) missing"
  exit 1
fi

echo "Verifying pgcrypto extension..."
pgcrypto="$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT COUNT(*) FROM pg_extension WHERE extname = 'pgcrypto';")"
if [[ "$pgcrypto" != "1" ]]; then
  echo "FAIL: pgcrypto extension not installed"
  exit 1
fi

echo "Verifying max-5-children trigger..."
docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO users (email, password_hash, role, region)
VALUES ('parent@test.local', 'hash', 'parent', 'us-central1');

DO $$
DECLARE
  parent_uuid UUID;
  i INT;
BEGIN
  SELECT user_id INTO parent_uuid FROM users WHERE email = 'parent@test.local';
  FOR i IN 1..5 LOOP
    INSERT INTO child_profiles (parent_id, display_name, age_range, pin_hash)
    VALUES (parent_uuid, 'Child ' || i, '6-8', 'pinhash');
  END LOOP;
  BEGIN
    INSERT INTO child_profiles (parent_id, display_name, age_range, pin_hash)
    VALUES (parent_uuid, 'Child 6', '6-8', 'pinhash');
    RAISE EXCEPTION 'expected max-children trigger to block 6th child';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%maximum of 5 child profiles%' THEN
        RAISE;
      END IF;
  END;
END $$;
SQL

echo "Verifying child_session_config defaults..."
defaults_ok="$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT column_default LIKE '%300%' FROM information_schema.columns WHERE table_name = 'child_session_config' AND column_name = 'min_duration_sec';")"
if [[ "$defaults_ok" != "t" ]]; then
  echo "FAIL: child_session_config.min_duration_sec default not 300"
  exit 1
fi

echo "All schema integration tests passed"
