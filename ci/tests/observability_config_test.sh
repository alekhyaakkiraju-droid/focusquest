#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

failures=0

assert_contains() {
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

assert_contains "packages/shared/middleware/logging.go" "request_id" "Structured logging includes request_id"
assert_contains "packages/shared/middleware/logging.go" "latency_ms" "Structured logging includes latency_ms"
assert_contains "packages/shared/middleware/request_id.go" "X-Request-ID" "Request ID header constant defined"
assert_contains "packages/shared/middleware/tracing.go" "otelhttp" "Cloud Trace integration via OpenTelemetry HTTP instrumentation"
assert_contains "infrastructure/terraform/modules/monitoring/main.tf" "retention_days = 400" "Log retention configured for at least 1 year"
assert_contains "infrastructure/terraform/modules/monitoring/alerts.tf" "P95 latency" "P95 latency alert configured"
assert_contains "infrastructure/terraform/modules/monitoring/alerts.tf" "Error rate" "Error rate alert configured"
assert_contains "infrastructure/terraform/modules/monitoring/alerts.tf" "401" "401 spike alert configured"
assert_contains "infrastructure/terraform/modules/monitoring/main.tf" "Latency Percentiles" "Monitoring dashboard includes latency percentiles"

for svc in auth-service timer-service quest-service notification-service compliance-service analytics-service; do
  assert_contains "services/${svc}/main.go" "shared/middleware" "${svc} uses shared observability middleware"
done

if [[ "$failures" -gt 0 ]]; then
  echo "$failures observability configuration test(s) failed"
  exit 1
fi

echo "All observability configuration contract tests passed"
