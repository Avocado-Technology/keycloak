#!/usr/bin/env bash
# Static checks for production docker-compose and deploy workflow.
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

COMPOSE_FILE="deploy/production/docker-compose.yml"
[[ -f "$COMPOSE_FILE" ]] || fail "$COMPOSE_FILE missing"
grep -q "quay.io/keycloak/keycloak" "$COMPOSE_FILE" || fail "keycloak image not defined"
grep -q "avcd_edge" "$COMPOSE_FILE" || fail "avcd_edge network not defined"
grep -q "traefik.enable=true" "$COMPOSE_FILE" || fail "Traefik labels missing"
grep -q "env_file:" "$COMPOSE_FILE" || fail "env_file not configured"
grep -q ".env.infisical" "$COMPOSE_FILE" || fail ".env.infisical not referenced"
grep -q "KC_DB_URL" "$COMPOSE_FILE" || fail "KC_DB_URL not configured"
grep -q "KEYCLOAK_HOST" "$COMPOSE_FILE" || fail "KEYCLOAK_HOST not configured"
grep -q -- "--import-realm" "$COMPOSE_FILE" && fail "production compose must not use --import-realm (IdP config via avcd-infra Terraform)"
grep -q "avcd-realm.prod.json" "$COMPOSE_FILE" && fail "production compose must not mount prod realm JSON"
if grep -q "ports:" "$COMPOSE_FILE"; then
  fail "production compose must not publish host ports"
fi
pass "production docker-compose structure"

[[ -f config/avcd-realm.prod.json ]] || fail "config/avcd-realm.prod.json missing (deprecated reference)"
grep -q 'DEPRECATED' config/avcd-realm.prod.json || fail "avcd-realm.prod.json must be marked deprecated"
pass "production realm JSON deprecated"

[[ -f deploy/production/.env.infisical.example ]] || fail ".env.infisical.example missing"
for key in KC_DB_URL KC_DB_USERNAME KC_DB_PASSWORD KEYCLOAK_ADMIN KEYCLOAK_ADMIN_PASSWORD KEYCLOAK_HOST; do
  grep -q "$key" deploy/production/.env.infisical.example || fail ".env.infisical.example missing $key"
done
pass ".env.infisical.example keys"

echo "Validating compose config with placeholder env..."
(
  cd deploy/production
  export KEYCLOAK_HOST=auth.ci.validate.local
  export KC_DB_URL='jdbc:postgresql://h:25060/keycloak?sslmode=require'
  export KC_DB_USERNAME=keycloak
  export KC_DB_PASSWORD=placeholder
  export KEYCLOAK_ADMIN=admin
  export KEYCLOAK_ADMIN_PASSWORD=placeholder
  touch .env.infisical
  docker compose -f docker-compose.yml config >/dev/null
)
pass "docker compose config"

echo "All production config checks passed."
