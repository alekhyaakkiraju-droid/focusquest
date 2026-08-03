#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "=== CI script tests ==="
bash ci/tests/check_npm_packages_test.sh
bash ci/tests/check_sensitive_files_test.sh
bash ci/tests/cloudbuild_config_test.sh
bash ci/tests/observability_config_test.sh
bash ci/tests/schema_config_test.sh
bash ci/tests/encryption_config_test.sh

echo "=== Database schema tests ==="
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  bash services/database/tests/schema_test.sh
  bash services/database/tests/encryption_integration_test.sh
else
  echo "SKIP: Docker unavailable; schema integration test skipped"
  echo "SKIP: Docker unavailable; encryption integration test skipped"
fi

echo "=== Repository policy checks ==="
bash ci/check-npm-packages-in-commit.sh
bash ci/check-sensitive-files.sh

echo "All CI tests passed"
