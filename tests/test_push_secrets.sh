#!/usr/bin/env bash
# Assert Makefile can upload app + bootstrap secrets to Infisical (prod).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAKEFILE="$ROOT/Makefile"
PROJECT_ID="db036f0e-7452-4e17-9573-e5471b45d65f"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

[[ -f "$MAKEFILE" ]] || fail "Makefile missing"
grep -q '^push-secrets:' "$MAKEFILE" || fail "push-secrets target missing"
grep -q '^push-bootstrap:' "$MAKEFILE" || fail "push-bootstrap target missing"
grep -q 'infisical secrets set' "$MAKEFILE" || fail "infisical secrets set not used"
grep -q 'INFISICAL_SECRET_PATH' "$MAKEFILE" || fail "INFISICAL_SECRET_PATH not referenced"
grep -q '/ci-bootstrap' "$MAKEFILE" || fail "/ci-bootstrap path not referenced"
grep -q 'DO_DEPLOY_SSH_KEY' "$MAKEFILE" || fail "DO_DEPLOY_SSH_KEY not referenced"
grep -q "$PROJECT_ID" "$MAKEFILE" || fail "prod project id default missing"
grep -q 'SSH_KEY_FILE' "$MAKEFILE" || fail "SSH_KEY_FILE not referenced"
pass "Makefile push-secrets and push-bootstrap targets"
