#!/usr/bin/env bash
# Static checks for deploy-keycloak-dev.yml workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/deploy-keycloak-dev.yml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

[[ -f "$WORKFLOW" ]] || fail "deploy-keycloak-dev.yml missing"
grep -q "Deploy Keycloak to DigitalOcean" "$WORKFLOW" || fail "workflow title missing"
grep -q "KEYCLOAK_INFISICAL_CLIENT_ID" "$WORKFLOW" || fail "KEYCLOAK_INFISICAL_CLIENT_ID not referenced"
grep -q "KEYCLOAK_INFISICAL_CLIENT_SECRET" "$WORKFLOW" || fail "KEYCLOAK_INFISICAL_CLIENT_SECRET not referenced"
grep -q "KEYCLOAK_INFISICAL_PROJECT_ID" "$WORKFLOW" || fail "KEYCLOAK_INFISICAL_PROJECT_ID not referenced"
grep -q "droplet-compose-deploy@v2" "$WORKFLOW" || fail "droplet-compose-deploy action missing"
grep -q "compose_subdirectory: deploy/production" "$WORKFLOW" || fail "compose_subdirectory missing"
grep -q "openid-configuration" "$WORKFLOW" || fail "OIDC discovery verify URL missing"
grep -q 'clear_published_ports: "none"' "$WORKFLOW" || fail "clear_published_ports should be none"
grep -q "KEYCLOAK_POSTGRES_BOOTSTRAP_URI" "$WORKFLOW" || fail "Postgres bootstrap secret not referenced"
grep -q "INFISICAL_SECRET_PATH" "$WORKFLOW" || fail "INFISICAL_SECRET_PATH not referenced"
grep -q "/keycloak" "$WORKFLOW" || fail "Infisical export path /keycloak missing"
grep -q "802aad98-56e1-4b3e-a0a9-68b3bfec4537" "$WORKFLOW" || fail "infra Infisical project ID missing"
pass "deploy-keycloak-dev.yml structure"

echo "All deploy workflow checks passed."
