#!/usr/bin/env bash
# Static checks for configure-google-idp.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

[[ -x scripts/configure-google-idp.sh ]] || fail "scripts/configure-google-idp.sh not executable"
grep -q 'GOOGLE_CLIENT_ID' scripts/configure-google-idp.sh || fail "configure script must require GOOGLE_CLIENT_ID"
grep -q 'GOOGLE_CLIENT_SECRET' scripts/configure-google-idp.sh || fail "configure script must require GOOGLE_CLIENT_SECRET"
grep -q 'identity-provider/instances/google' scripts/configure-google-idp.sh || fail "configure script must target google IdP"

if [[ -z "${GOOGLE_CLIENT_ID:-}" ]]; then
  if (unset GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET KEYCLOAK_ADMIN_PASSWORD; \
      source scripts/configure-google-idp.sh 2>/dev/null); then
    fail "configure script should fail without GOOGLE_CLIENT_ID"
  fi
  pass "configure script fails without GOOGLE_CLIENT_ID"
else
  pass "GOOGLE_CLIENT_ID present in environment (runtime check skipped)"
fi

echo "All configure-google-idp static checks passed."
