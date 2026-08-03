#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONTAINER_NAME="focusquest-encryption-test"
POSTGRES_USER="focusquest"
POSTGRES_PASSWORD="focusquest"
POSTGRES_DB="focusquest"
POSTGRES_PORT="${POSTGRES_PORT:-54330}"
DATABASE_URL="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:$POSTGRES_PORT/$POSTGRES_DB?sslmode=disable"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: Docker not available; encryption integration test skipped"
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  echo "SKIP: Docker daemon not running; encryption integration test skipped"
  exit 0
fi

echo "Starting Postgres for encryption integration test..."
cleanup
docker run -d \
  --name "$CONTAINER_NAME" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -p "$POSTGRES_PORT:5432" \
  postgres:16-alpine >/dev/null

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

echo "Applying migrations..."
for migration in "$ROOT/migrations"/*.up.sql; do
  docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$migration" >/dev/null
done

PARENT_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
CHILD_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
TENANT_KEY_ID="projects/local/locations/us-central1/keyRings/focusquest/cryptoKeys/tenant-${PARENT_ID}"
ENCRYPTED_NAME="fqenc:v1:YWJj"
ENCRYPTED_AGE="fqenc:v1:ZGVm"

docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL >/dev/null
INSERT INTO users (user_id, email, password_hash, role, region)
VALUES ('${PARENT_ID}', 'parent-${PARENT_ID}@example.com', 'hash', 'parent', 'us-central1');

INSERT INTO tenant_encryption_keys (parent_id, tenant_key_id, encrypted_dek, kek_version)
VALUES ('${PARENT_ID}', '${TENANT_KEY_ID}', decode('0011223344', 'hex'), 1);

INSERT INTO child_profiles (child_id, parent_id, display_name, age_range, pin_hash)
VALUES ('${CHILD_ID}', '${PARENT_ID}', '${ENCRYPTED_NAME}', '${ENCRYPTED_AGE}', 'pin-hash');
SQL

RAW_NAME="$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c \
  "SELECT display_name FROM child_profiles WHERE child_id = '${CHILD_ID}'")"
RAW_AGE="$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c \
  "SELECT age_range FROM child_profiles WHERE child_id = '${CHILD_ID}'")"

if [[ "$RAW_NAME" == "Maya" || "$RAW_AGE" == "7-9" ]]; then
  echo "FAIL: plaintext child PII found in database"
  exit 1
fi

if [[ "$RAW_NAME" != fqenc:v1:* || "$RAW_AGE" != fqenc:v1:* ]]; then
  echo "FAIL: child PII columns must store application-layer ciphertext"
  exit 1
fi

TABLE_EXISTS="$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c \
  "SELECT to_regclass('public.tenant_encryption_keys')")"
if [[ "$TABLE_EXISTS" != "tenant_encryption_keys" ]]; then
  echo "FAIL: tenant_encryption_keys table missing"
  exit 1
fi

echo "PASS: child PII stored as ciphertext in PostgreSQL"
echo "PASS: tenant_encryption_keys table present"
echo "Encryption integration test passed"
