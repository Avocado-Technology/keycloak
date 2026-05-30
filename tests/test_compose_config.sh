#!/usr/bin/env bash
# Static checks for repo layout and docker-compose configuration.
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

[[ -f README.md ]] || fail "README.md missing"
pass "README.md exists"

[[ -f .env.example ]] || fail ".env.example missing"
grep -q "KEYCLOAK_ADMIN" .env.example || fail ".env.example missing KEYCLOAK_ADMIN"
grep -q "KEYCLOAK_TEST_CLIENT_SECRET" .env.example || fail ".env.example missing test client secret"
pass ".env.example configured"

[[ -f docker-compose.yml ]] || fail "docker-compose.yml missing"
grep -q "quay.io/keycloak/keycloak" docker-compose.yml || fail "keycloak image not defined"
grep -q "postgres:16" docker-compose.yml || fail "postgres service not defined"
grep -q "healthcheck" docker-compose.yml || fail "healthcheck not configured"
pass "docker-compose.yml structure"

[[ -f config/avcd-realm.json ]] || fail "config/avcd-realm.json missing"
grep -q '"realm": "avcd"' config/avcd-realm.json || fail "avcd realm not defined"
grep -q 'avcd-validation' config/avcd-realm.json || fail "validation client not defined"
pass "realm import config"

[[ -x scripts/wait-for-keycloak.sh ]] || fail "scripts/wait-for-keycloak.sh not executable"
[[ -x scripts/e2e-local-validation.sh ]] || fail "scripts/e2e-local-validation.sh not executable"
pass "validation scripts present"

echo "All static config checks passed."
