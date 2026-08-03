#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "=== CI script tests ==="
bash ci/tests/check_npm_packages_test.sh
bash ci/tests/check_sensitive_files_test.sh
bash ci/tests/cloudbuild_config_test.sh

echo "=== Repository policy checks ==="
bash ci/check-npm-packages-in-commit.sh
bash ci/check-sensitive-files.sh

echo "All CI tests passed"
