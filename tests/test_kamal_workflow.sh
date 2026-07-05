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
echo "[prod] deploy-keycloak-kamal-prod.yml (retired — manual remove only)"
check "prod workflow exists" test -f "$PROD_WORKFLOW"
check "prod marked retired" grep -q 'RETIRED' "$PROD_WORKFLOW"
check "prod workflow_dispatch only" grep -q 'workflow_dispatch:' "$PROD_WORKFLOW" && ! grep -qE '^[[:space:]]*push:' "$PROD_WORKFLOW"
check "prod default kamal_command is remove" grep -q 'default: remove' "$PROD_WORKFLOW"
check "prod remove job uses SSH docker cleanup" grep -q 'Remove Keycloak containers via SSH' "$PROD_WORKFLOW"
check "prod remove job targets avcd-keycloak containers" grep -q 'avcd-keycloak' "$PROD_WORKFLOW"
check "prod id-token write" grep -q 'id-token: write' "$PROD_WORKFLOW"
check "prod deploy job gated off remove" grep -q "kamal_command != 'remove'" "$PROD_WORKFLOW"
if grep -q "$LEGACY_PROJECT_ID" "$PROD_WORKFLOW" 2>/dev/null; then
  echo "  ✗ prod no legacy project id"
  ((errors++)) || true
else
  echo "  ✓ prod no legacy project id"
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
