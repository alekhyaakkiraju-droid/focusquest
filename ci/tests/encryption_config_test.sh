#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

failures=0

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -q "$pattern" "$file"; then
    echo "FAIL: $message"
    failures=$((failures + 1))
  else
    echo "PASS: $message"
  fi
}

assert_file_exists() {
  local file="$1"
  local message="$2"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $message"
    failures=$((failures + 1))
  else
    echo "PASS: $message"
  fi
}

assert_file_exists "$ROOT/packages/shared/encryption/envelope.go" "shared encryption envelope.go exists"
assert_file_exists "$ROOT/packages/shared/encryption/kms_client.go" "shared encryption kms_client.go exists"
assert_file_exists "$ROOT/packages/shared/encryption/gcp_kms_client.go" "GCP KMS client exists"
assert_file_exists "$ROOT/services/auth-service/repository/child_profile_repo.go" "auth child profile repository exists"
assert_file_exists "$ROOT/services/quest-service/repository/quest_progress_repo.go" "quest progress repository exists"
assert_file_exists "$ROOT/services/database/migrations/011_encryption.up.sql" "tenant encryption migration exists"

assert_file_contains "$ROOT/packages/shared/encryption/envelope.go" "AES-256-GCM" "AES-256-GCM documented in envelope encryption"
assert_file_contains "$ROOT/packages/shared/encryption/envelope.go" "func (s \*Service) Encrypt" "Encrypt function exported"
assert_file_contains "$ROOT/packages/shared/encryption/envelope.go" "func (s \*Service) Decrypt" "Decrypt function exported"
assert_file_contains "$ROOT/packages/shared/encryption/envelope.go" "RotateKEK" "envelope key rotation supported"
assert_file_contains "$ROOT/services/auth-service/repository/child_profile_repo.go" "display_name" "auth repo encrypts display_name"
assert_file_contains "$ROOT/services/auth-service/repository/child_profile_repo.go" "age_range" "auth repo encrypts age_range"
assert_file_contains "$ROOT/services/database/migrations/011_encryption.up.sql" "tenant_encryption_keys" "tenant_encryption_keys table defined"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures encryption contract check(s) failed"
  exit 1
fi

echo "All encryption contract checks passed"
