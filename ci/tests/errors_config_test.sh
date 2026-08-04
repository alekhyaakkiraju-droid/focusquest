#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

failures=0

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

assert_file_exists "$ROOT/packages/shared/errors/types.go" "shared error types.go exists"
assert_file_exists "$ROOT/packages/shared/errors/response.go" "shared error response.go exists"
assert_file_exists "$ROOT/packages/shared/errors/circuit_breaker.go" "circuit breaker exists"
assert_file_exists "$ROOT/packages/shared/errors/retry.go" "retry logic exists"

assert_file_contains "$ROOT/packages/shared/errors/types.go" "ValidationError" "ValidationError defined"
assert_file_contains "$ROOT/packages/shared/errors/types.go" "AuthenticationError" "AuthenticationError defined"
assert_file_contains "$ROOT/packages/shared/errors/types.go" "AuthorizationError" "AuthorizationError defined"
assert_file_contains "$ROOT/packages/shared/errors/types.go" "NotFoundError" "NotFoundError defined"
assert_file_contains "$ROOT/packages/shared/errors/types.go" "RateLimitError" "RateLimitError defined"
assert_file_contains "$ROOT/packages/shared/errors/types.go" "InternalError" "InternalError defined"
assert_file_contains "$ROOT/packages/shared/errors/types.go" "error_code" "standard error_code JSON field"
assert_file_contains "$ROOT/packages/shared/errors/circuit_breaker.go" "FailureThreshold: 5" "default circuit breaker threshold configured"
assert_file_contains "$ROOT/packages/shared/errors/circuit_breaker.go" "30 \* time.Second" "default circuit breaker window configured"
assert_file_contains "$ROOT/packages/shared/errors/circuit_breaker.go" "60 \* time.Second" "default half-open retry configured"
assert_file_contains "$ROOT/packages/shared/errors/retry.go" "MaxRetries: 3" "default max retries configured"
assert_file_contains "$ROOT/packages/shared/errors/retry.go" "100 \* time.Millisecond" "default retry base delay configured"
assert_file_contains "$ROOT/packages/shared/errors/response.go" "emitServerErrorLog" "5xx errors emit structured logs"

for svc in auth-service timer-service quest-service notification-service compliance-service analytics-service; do
  assert_file_contains "$ROOT/services/${svc}/main.go" "shared/errors" "${svc} uses shared error handling"
done

if [[ "$failures" -gt 0 ]]; then
  echo "$failures error handling contract check(s) failed"
  exit 1
fi

echo "All error handling contract checks passed"
