#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/ci/check-npm-packages-in-commit.sh"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"
git init -q
git config user.email "ci@test.local"
git config user.name "CI Test"

mkdir -p ci
cp "$SCRIPT" ci/check-npm-packages-in-commit.sh
chmod +x ci/check-npm-packages-in-commit.sh

failures=0

run_pass_test() {
  local name="$1"
  if bash ci/check-npm-packages-in-commit.sh >/dev/null 2>&1; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

run_fail_test() {
  local name="$1"
  if bash ci/check-npm-packages-in-commit.sh >/dev/null 2>&1; then
    echo "FAIL: $name (expected failure)"
    failures=$((failures + 1))
  else
    echo "PASS: $name"
  fi
}

# Clean repo should pass
echo "README" > README.md
git add README.md
git commit -q -m "init"
run_pass_test "clean repo passes"

# node_modules content should fail
mkdir -p node_modules/pkg
echo "module" > node_modules/pkg/index.js
git add node_modules/pkg/index.js
git commit -q -m "add node_modules"
run_fail_test "tracked node_modules fails"

# Reset for tgz test
cd "$WORKDIR"
rm -rf "$WORKDIR"/*
git init -q
git config user.email "ci@test.local"
git config user.name "CI Test"
mkdir -p ci
cp "$SCRIPT" ci/check-npm-packages-in-commit.sh
chmod +x ci/check-npm-packages-in-commit.sh
echo "ok" > README.md
git add README.md
git commit -q -m "init"
echo "pkg" > focusquest-1.0.0.tgz
git add focusquest-1.0.0.tgz
git commit -q -m "add tgz"
run_fail_test "tracked .tgz fails"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures npm package check test(s) failed"
  exit 1
fi

echo "All npm package check tests passed"
