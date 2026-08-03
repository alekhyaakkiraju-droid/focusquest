#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/ci/check-sensitive-files.sh"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"
git init -q
git config user.email "ci@test.local"
git config user.name "CI Test"

mkdir -p ci
cp "$SCRIPT" ci/check-sensitive-files.sh
chmod +x ci/check-sensitive-files.sh

failures=0

run_pass_test() {
  local name="$1"
  if bash ci/check-sensitive-files.sh >/dev/null 2>&1; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

run_fail_test() {
  local name="$1"
  if bash ci/check-sensitive-files.sh >/dev/null 2>&1; then
    echo "FAIL: $name (expected failure)"
    failures=$((failures + 1))
  else
    echo "PASS: $name"
  fi
}

echo "README" > README.md
echo "EXAMPLE=1" > .env.example
git add README.md .env.example
git commit -q -m "init"
run_pass_test ".env.example is allowed"

echo "SECRET=bad" > .env
git add .env
git commit -q -m "add env"
run_fail_test ".env fails"

cd "$WORKDIR"
rm -rf "$WORKDIR"/*
git init -q
git config user.email "ci@test.local"
git config user.name "CI Test"
mkdir -p ci
cp "$SCRIPT" ci/check-sensitive-files.sh
chmod +x ci/check-sensitive-files.sh
echo "ok" > README.md
git add README.md
git commit -q -m "init"
echo "key" > server.pem
git add server.pem
git commit -q -m "add pem"
run_fail_test "*.pem fails"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures sensitive file check test(s) failed"
  exit 1
fi

echo "All sensitive file check tests passed"
