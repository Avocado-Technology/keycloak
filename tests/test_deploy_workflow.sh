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
grep -q "INFISICAL_OIDC_IDENTITY_ID" "$WORKFLOW" || fail "INFISICAL_OIDC_IDENTITY_ID not referenced"
grep -q "id-token: write" "$WORKFLOW" || fail "OIDC requires id-token write permission"
grep -q 'method=oidc-auth' "$WORKFLOW" || fail "Infisical login must use oidc-auth"
grep -q 'machine-identity-id' "$WORKFLOW" || fail "Infisical login must pass machine-identity-id"
grep -q 'ACTIONS_ID_TOKEN_REQUEST' "$WORKFLOW" || fail "GitHub OIDC token request missing"
grep -q "KEYCLOAK_INFISICAL_CLIENT_ID" "$WORKFLOW" && fail "legacy KEYCLOAK_INFISICAL_CLIENT_ID still referenced"
grep -q "droplet-compose-deploy@v2" "$WORKFLOW" || fail "droplet-compose-deploy action missing"
grep -q "compose_subdirectory: deploy/production" "$WORKFLOW" || fail "compose_subdirectory missing"
grep -q "openid-configuration" "$WORKFLOW" || fail "OIDC discovery verify URL missing"
grep -q 'clear_published_ports: "none"' "$WORKFLOW" || fail "clear_published_ports should be none"
grep -q "KEYCLOAK_POSTGRES_BOOTSTRAP_URI" "$WORKFLOW" || fail "Postgres bootstrap URI must come from Infisical export"
grep -q "DO_DEPLOY_HOST" "$WORKFLOW" || fail "DO_DEPLOY_HOST must come from Infisical export"
grep -q "/keycloak" "$WORKFLOW" || fail "Infisical export path /keycloak missing"
grep -q "802aad98-56e1-4b3e-a0a9-68b3bfec4537" "$WORKFLOW" || fail "infra Infisical project ID missing"
grep -q "steps.deploy.outputs.deploy_host" "$WORKFLOW" || fail "deploy host must use Infisical-derived outputs"
pass "deploy-keycloak-dev.yml structure"

echo "All deploy workflow checks passed."
