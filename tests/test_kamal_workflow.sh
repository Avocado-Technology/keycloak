#!/usr/bin/env bash
# Test script for Kamal workflows (Phase 3 Gate)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROD_WORKFLOW="$REPO_DIR/.github/workflows/deploy-keycloak-kamal-prod.yml"
LEGACY_PROJECT_ID="802aad98-56e1-4b3e-a0a9-68b3bfec4537"

errors=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "  ✓ $desc"
  else
    echo "  ✗ $desc"
    ((errors++)) || true
  fi
}

echo "=== Testing Kamal Workflows ==="
echo ""

echo "[repo] no second Keycloak deploy workflow"
check "deploy-keycloak-kamal-dev.yml removed" test ! -f "$REPO_DIR/.github/workflows/deploy-keycloak-kamal-dev.yml"

echo ""
echo "[prod] deploy-keycloak-kamal-prod.yml (infra — shared IdP)"
check "prod workflow exists" test -f "$PROD_WORKFLOW"
check "prod documents shared IdP URL" grep -q 'auth.avcd.ai' "$PROD_WORKFLOW" && grep -q 'dev and prod' "$PROD_WORKFLOW"
check "prod documents Infisical parity" grep -q 'Infisical' "$PROD_WORKFLOW"
check "prod uses production GitHub env for OIDC claim" grep -qE '^[[:space:]]*environment:[[:space:]]*production' "$PROD_WORKFLOW"
check "prod OIDC audience is secrets.avcd.ai (pulumi keycloak-ci)" grep -q 'secrets.avcd.ai' "$PROD_WORKFLOW"
check "prod uses pulumi keycloak-ci identity at repo level" grep -q 'INFISICAL_OIDC_IDENTITY_ID' "$PROD_WORKFLOW"
check "prod id-token write" grep -q 'id-token: write' "$PROD_WORKFLOW"
check "prod OIDC infisical login" grep -q 'infisical login --method=oidc-auth' "$PROD_WORKFLOW"
check "prod exports /keycloak" grep -q 'INFISICAL_SECRET_PATH.*/keycloak\|path=.*/keycloak\|/keycloak' "$PROD_WORKFLOW"
check "prod exports /ci-bootstrap for SSH" grep -q '/ci-bootstrap' "$PROD_WORKFLOW"
check "prod pins avcd-actions ref" grep -qE 'ref:[[:space:]]*2e0e1b5' "$PROD_WORKFLOW"
check "prod uses internal avcd-actions checkout" grep -q 'Avocado-Technology/avcd-actions' "$PROD_WORKFLOW" && grep -q 'GH_INFRA_TOKEN' "$PROD_WORKFLOW"
check "prod uses local kamal-deploy composite" grep -q './avcd-actions/kamal-deploy' "$PROD_WORKFLOW"
if grep -q "$LEGACY_PROJECT_ID" "$PROD_WORKFLOW" 2>/dev/null; then
  echo "  ✗ prod no legacy project id"
  ((errors++)) || true
else
  echo "  ✓ prod no legacy project id"
fi
check "prod localhost registry input" grep -q 'localhost:5555' "$PROD_WORKFLOW"
check "prod kamal push enabled" grep -q 'skip_registry_login: "false"' "$PROD_WORKFLOW"
check "prod OIDC discovery verify_url" grep -q 'verify_url:' "$PROD_WORKFLOW" && grep -q 'openid-configuration' "$PROD_WORKFLOW"
check "prod skip_accessory_boot" grep -q 'skip_accessory_boot' "$PROD_WORKFLOW"
check "prod renders .kamal/secrets in Infisical step" grep -q 'secrets.ci.template' "$PROD_WORKFLOW"
check "prod skip_secrets_render for kamal-deploy" grep -q 'skip_secrets_render' "$PROD_WORKFLOW"
if grep -q 'Preprocess deploy.yml' "$PROD_WORKFLOW" 2>/dev/null; then
  echo "  ✗ prod should not duplicate preprocess deploy.yml (kamal-deploy renders)"
  ((errors++)) || true
else
  echo "  ✓ prod no duplicate preprocess deploy.yml step"
fi

echo ""
echo "[sync] sync-infisical-secrets.yml"
SYNC_WORKFLOW="$REPO_DIR/.github/workflows/sync-infisical-secrets.yml"
check "sync workflow exists" test -f "$SYNC_WORKFLOW"
check "sync workflow_dispatch" grep -q 'workflow_dispatch:' "$SYNC_WORKFLOW"
check "sync workflow_call" grep -q 'workflow_call:' "$SYNC_WORKFLOW"
check "sync uses pulumi-secrets action" grep -q 'pulumi-secrets' "$SYNC_WORKFLOW"
check "sync requires Infisical client secrets" grep -q 'INFISICAL_CLIENT_ID' "$SYNC_WORKFLOW"

echo ""
echo "[repo] legacy cleanup"
check "legacy deploy-keycloak-dev.yml removed" test ! -f "$REPO_DIR/.github/workflows/deploy-keycloak-dev.yml"
check "legacy deploy/production removed" test ! -d "$REPO_DIR/deploy/production"

echo ""
if [ $errors -eq 0 ]; then
    echo "=== All workflow tests passed ✓ ==="
    exit 0
else
    echo "=== $errors workflow test(s) failed ✗ ==="
    exit 1
fi
