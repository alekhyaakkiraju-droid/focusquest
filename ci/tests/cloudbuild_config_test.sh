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

services=(
  auth-service
  timer-service
  quest-service
  notification-service
  compliance-service
  analytics-service
)

for svc in "${services[@]}"; do
  file="services/$svc/cloudbuild.yaml"
  assert_contains "$file" "go test" "$svc cloudbuild runs unit tests"
  assert_contains "$file" "trivy image" "$svc cloudbuild includes trivy scan step"
  assert_contains "$file" "gcloud run deploy" "$svc cloudbuild deploys to Cloud Run staging"
  assert_contains "services/$svc/Dockerfile" "distroless" "$svc Dockerfile uses minimal runtime image"
done

assert_contains "apps/flutter-app/cloudbuild.yaml" "flutter build apk" "Flutter pipeline builds APK"
assert_contains "apps/flutter-app/cloudbuild.yaml" "flutter build appbundle" "Flutter pipeline builds AAB"
assert_contains "apps/flutter-app/cloudbuild.yaml" "flutter build ipa" "Flutter pipeline includes IPA step"

assert_contains "apps/parent-dashboard/cloudbuild.yaml" "npm run build" "Dashboard pipeline builds production bundle"
assert_contains "apps/parent-dashboard/cloudbuild.yaml" "gsutil" "Dashboard pipeline deploys to GCS"
assert_contains "apps/parent-dashboard/cloudbuild.yaml" "invalidate-cdn-cache" "Dashboard pipeline invalidates CDN cache"

assert_contains ".github/workflows/security-checks.yml" "check-npm-packages-in-commit.sh" "Security workflow blocks npm packages in commits"
assert_contains ".github/workflows/security-checks.yml" "check-sensitive-files.sh" "Security workflow blocks sensitive files"
assert_contains ".github/workflows/backend-ci.yml" "matrix:" "Backend workflow uses service matrix"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures cloudbuild configuration test(s) failed"
  exit 1
fi

echo "All cloudbuild configuration contract tests passed"
