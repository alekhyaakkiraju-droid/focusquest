#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

required_topics=(
  session-completed
  quest-progress
  xp-awarded
  notification-send
  consent-recorded
  data-deletion-requested
)

for topic in "${required_topics[@]}"; do
  assert_contains "variables.tf" "$topic" "Pub/Sub topic '$topic' declared in root variables"
done

assert_contains "variables.tf" "us-central1" "US region configured"
assert_contains "variables.tf" "europe-west1" "EU region configured"
assert_contains "modules/kms/main.tf" "7776000s" "KMS 90-day rotation configured"
assert_contains "modules/cloudsql/main.tf" "db-custom-4-16384" "Cloud SQL tier configured"
assert_contains "modules/cloudsql/main.tf" "REGIONAL" "Cloud SQL HA failover configured"
assert_contains "modules/cloudsql/main.tf" "ipv4_enabled    = false" "Cloud SQL public IP disabled"
assert_contains "modules/cloudsql/main.tf" "encryption_key_name" "Cloud SQL CMEK configured"
assert_contains "modules/redis/main.tf" "SERVER_AUTHENTICATION" "Redis TLS transit encryption configured"
assert_contains "modules/storage/main.tf" "uniform_bucket_level_access = true" "Avatar bucket uniform access configured"
assert_contains "modules/storage/main.tf" "cors" "Avatar bucket CORS configured for CDN"
assert_contains "modules/cloud_armor/main.tf" "evaluatePreconfiguredExpr" "Cloud Armor OWASP rules configured"
assert_contains "modules/vpc_service_controls/main.tf" "google_access_context_manager_service_perimeter" "VPC Service Controls perimeter configured"
assert_contains "main.tf" "module \"cloudsql\"" "Dual-region Cloud SQL module wired"
assert_contains "main.tf" "module \"monitoring\"" "Monitoring module wired in root terraform"
assert_contains "modules/monitoring/main.tf" "google_monitoring_dashboard" "Monitoring dashboard resource configured"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures configuration test(s) failed"
  exit 1
fi

echo "All configuration contract tests passed"
