#!/usr/bin/env bash
# Fails if npm package archives or node_modules content are tracked in git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: Not inside a git repository."
  exit 1
fi

violations=()

while IFS= read -r file; do
  [[ -n "$file" ]] && violations+=("$file")
done < <(git ls-files 'node_modules' 'node_modules/**' '**/node_modules/**' 2>/dev/null || true)

while IFS= read -r file; do
  [[ -n "$file" ]] && violations+=("$file")
done < <(git ls-files '*.tgz' '**/*.tgz' 2>/dev/null || true)

if [[ "${#violations[@]}" -gt 0 ]]; then
  echo "ERROR: Committed npm package artifacts detected (org policy violation):"
  printf '  - %s\n' "${violations[@]}"
  echo "Remove these files from git tracking and rely on lockfiles instead."
  exit 1
fi

echo "PASS: No committed npm package artifacts detected."
