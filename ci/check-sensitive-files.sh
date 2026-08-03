#!/usr/bin/env bash
# Fails if sensitive credential files are tracked in git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: Not inside a git repository."
  exit 1
fi

patterns=(
  '.env'
  '**/.env'
  '*.pem'
  '**/*.pem'
  '*.key'
  '**/*.key'
  'credentials.json'
  '**/credentials.json'
  'service-account*.json'
  '**/service-account*.json'
)

violations=()

for pattern in "${patterns[@]}"; do
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    allowed=false
    if [[ "$file" == ".env.example" || "$file" == *"/.env.example" || "$file" == "terraform.tfvars.example" || "$file" == *"/terraform.tfvars.example" ]]; then
      allowed=true
    fi
    if [[ "$allowed" == false ]]; then
      violations+=("$file")
    fi
  done < <(git ls-files "$pattern" 2>/dev/null || true)
done

if [[ "${#violations[@]}" -gt 0 ]]; then
  echo "ERROR: Sensitive files detected in git (org policy violation):"
  printf '  - %s\n' "${violations[@]}"
  echo "Use secret managers or CI variables instead of committing credentials."
  exit 1
fi

echo "PASS: No sensitive files detected in git."
