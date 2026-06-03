#!/usr/bin/env bash
# Test script for Kamal workflows (Phase 3 Gate)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEV_WORKFLOW="$REPO_DIR/.github/workflows/deploy-keycloak-kamal-dev.yml"
PROD_WORKFLOW="$REPO_DIR/.github/workflows/deploy-keycloak-kamal-prod.yml"
PROJECT_ID="db036f0e-7452-4e17-9573-e5471b45d65f"
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

echo "[dev] deploy-keycloak-kamal-dev.yml"
check "dev workflow exists" test -f "$DEV_WORKFLOW"
check "dev uses kamal-deploy@v5" grep -q 'Avocado-Technology/avcd-actions/kamal-deploy@v5' "$DEV_WORKFLOW"
check "dev id-token write" grep -q 'id-token: write' "$DEV_WORKFLOW"
check "dev OIDC infisical login" grep -q 'infisical login --method=oidc-auth' "$DEV_WORKFLOW"
check "dev exports /keycloak" grep -q '/keycloak' "$DEV_WORKFLOW"
check "dev workflow_dispatch kamal_command" grep -q 'kamal_command:' "$DEV_WORKFLOW"

echo ""
echo "[prod] deploy-keycloak-kamal-prod.yml"
check "prod workflow exists" test -f "$PROD_WORKFLOW"
check "prod environment production" grep -q 'environment: production' "$PROD_WORKFLOW"
check "prod id-token write" grep -q 'id-token: write' "$PROD_WORKFLOW"
check "prod OIDC infisical login" grep -q 'infisical login --method=oidc-auth' "$PROD_WORKFLOW"
check "prod exports /keycloak" grep -q 'INFISICAL_SECRET_PATH.*/keycloak\|path=.*/keycloak\|/keycloak' "$PROD_WORKFLOW"
check "prod exports /ci-bootstrap for SSH" grep -q '/ci-bootstrap' "$PROD_WORKFLOW"
check "prod uses internal avcd-actions checkout" grep -q 'Avocado-Technology/avcd-actions' "$PROD_WORKFLOW" && grep -q 'GH_INFRA_TOKEN' "$PROD_WORKFLOW"
check "prod uses local kamal-deploy composite" grep -q './avcd-actions/kamal-deploy' "$PROD_WORKFLOW"
check "prod project id db036f0e" grep -q "$PROJECT_ID" "$PROD_WORKFLOW"
if grep -q "$LEGACY_PROJECT_ID" "$PROD_WORKFLOW" 2>/dev/null; then
  echo "  ✗ prod no legacy project id"
  ((errors++)) || true
else
  echo "  ✓ prod no legacy project id"
fi
check "prod skip_registry_login quay" grep -q 'skip_registry_login' "$PROD_WORKFLOW"
check "prod health verify URL" grep -q 'health/ready' "$PROD_WORKFLOW"
check "prod Set Kamal verify URL step" grep -q 'Set Kamal verify URL' "$PROD_WORKFLOW"
check "prod verify_url from kamal_verify output" grep -q 'steps.kamal_verify.outputs.url' "$PROD_WORKFLOW"
check "prod skips verify on setup" grep -q 'kamal_command' "$PROD_WORKFLOW" && \
  grep -q 'deploy.*redeploy' "$PROD_WORKFLOW" && \
  ! grep -q 'verify_url: https://\${{ steps.infisical.outputs.keycloak_host }}' "$PROD_WORKFLOW"
check "prod renders .kamal/secrets in Infisical step" grep -q 'secrets.ci.template' "$PROD_WORKFLOW"
check "prod skip_secrets_render for kamal-deploy" grep -q 'skip_secrets_render' "$PROD_WORKFLOW"
check "prod short edge verify retry budget" grep -q 'verify_retry_max_time: "30"' "$PROD_WORKFLOW"
if grep -q 'Preprocess deploy.yml' "$PROD_WORKFLOW" 2>/dev/null; then
  echo "  ✗ prod should not duplicate preprocess deploy.yml (kamal-deploy renders)"
  ((errors++)) || true
else
  echo "  ✓ prod no duplicate preprocess deploy.yml step"
fi

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
