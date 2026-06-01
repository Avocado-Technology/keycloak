#!/usr/bin/env bash
# Test script for Kamal workflows (Phase 3 Gate)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEV_WORKFLOW="$REPO_DIR/.github/workflows/deploy-keycloak-kamal-dev.yml"
PROD_WORKFLOW="$REPO_DIR/.github/workflows/deploy-keycloak-kamal-prod.yml"

errors=0

echo "=== Testing Kamal Workflows ==="
echo ""

# Test 1: Dev workflow exists
echo "[1/15] Checking dev workflow exists..."
if [ -f "$DEV_WORKFLOW" ]; then
    echo "  ✓ deploy-keycloak-kamal-dev.yml exists"
else
    echo "  ✗ deploy-keycloak-kamal-dev.yml not found"
    ((errors++))
fi

# Test 2: Prod workflow exists
echo "[2/15] Checking prod workflow exists..."
if [ -f "$PROD_WORKFLOW" ]; then
    echo "  ✓ deploy-keycloak-kamal-prod.yml exists"
else
    echo "  ✗ deploy-keycloak-kamal-prod.yml not found"
    ((errors++))
fi

# Test 3: Dev workflow uses kamal-deploy@v5
echo "[3/15] Checking dev workflow uses kamal-deploy@v5..."
if grep -q 'Avocado-Technology/avcd-actions/kamal-deploy@v5' "$DEV_WORKFLOW"; then
    echo "  ✓ Dev workflow uses kamal-deploy@v5"
else
    echo "  ✗ Dev workflow missing kamal-deploy@v5"
    ((errors++))
fi

# Test 4: id-token: write permission
echo "[4/15] Checking id-token: write permission..."
if grep -q 'id-token: write' "$DEV_WORKFLOW"; then
    echo "  ✓ id-token: write permission present"
else
    echo "  ✗ id-token: write permission missing"
    ((errors++))
fi

# Test 5: OIDC export for Infisical
echo "[5/15] Checking OIDC export for Infisical..."
if grep -q 'infisical login --method=oidc-auth' "$DEV_WORKFLOW"; then
    echo "  ✓ OIDC authentication configured"
else
    echo "  ✗ OIDC authentication not found"
    ((errors++))
fi

# Test 6: KEYCLOAK_HOST sed replacement
echo "[6/15] Checking KEYCLOAK_HOST sed replacement..."
if grep -q 'sed.*__KEYCLOAK_HOST__' "$DEV_WORKFLOW"; then
    echo "  ✓ KEYCLOAK_HOST sed replacement present"
else
    echo "  ✗ KEYCLOAK_HOST sed replacement missing"
    ((errors++))
fi

# Test 7: Postgres GRANT step retained
echo "[7/15] Checking Postgres GRANT step retained..."
if grep -q 'GRANT ALL ON SCHEMA public TO keycloak' "$DEV_WORKFLOW" && \
   grep -q 'KEYCLOAK_POSTGRES_BOOTSTRAP_URI' "$DEV_WORKFLOW"; then
    echo "  ✓ Postgres GRANT step retained"
else
    echo "  ✗ Postgres GRANT step missing or incomplete"
    ((errors++))
fi

# Test 8: Discovery URL verification with "issuer" check
echo "[8/15] Checking discovery URL verification..."
if grep -q 'well-known/openid-configuration' "$DEV_WORKFLOW" && \
   grep -q '"issuer"' "$DEV_WORKFLOW"; then
    echo "  ✓ Discovery URL verification with issuer check"
else
    echo "  ✗ Discovery URL verification incomplete"
    ((errors++))
fi

# Test 9: Legacy workflow removed
echo "[9/15] Checking legacy workflow removed..."
if [ ! -f "$REPO_DIR/.github/workflows/deploy-keycloak-dev.yml" ]; then
    echo "  ✓ Legacy workflow (deploy-keycloak-dev.yml) removed"
else
    echo "  ✗ Legacy workflow still exists"
    ((errors++))
fi

# Test 10: Legacy deploy directory removed
echo "[10/15] Checking legacy deploy/production removed..."
if [ ! -d "$REPO_DIR/deploy/production" ]; then
    echo "  ✓ Legacy deploy/production directory removed"
else
    echo "  ✗ Legacy deploy/production directory still exists"
    ((errors++))
fi

# Test 11: Prod workflow differs by environment
echo "[11/15] Checking prod workflow uses production environment..."
if grep -q 'environment: production' "$PROD_WORKFLOW"; then
    echo "  ✓ Prod workflow uses production environment"
else
    echo "  ✗ Prod workflow missing production environment"
    ((errors++))
fi

# Test 12: Prod workflow also uses kamal-deploy
echo "[12/15] Checking prod workflow uses kamal-deploy..."
if grep -q 'Avocado-Technology/avcd-actions/kamal-deploy@v5' "$PROD_WORKFLOW"; then
    echo "  ✓ Prod workflow uses kamal-deploy@v5"
else
    echo "  ✗ Prod workflow missing kamal-deploy"
    ((errors++))
fi

# Test 13: Workflow dispatch with kamal_command
echo "[13/15] Checking workflow_dispatch with kamal_command..."
if grep -q 'kamal_command:' "$DEV_WORKFLOW" && \
   grep -q 'setup' "$DEV_WORKFLOW" && \
   grep -q 'deploy' "$DEV_WORKFLOW"; then
    echo "  ✓ Workflow dispatch with kamal_command options"
else
    echo "  ✗ Workflow dispatch kamal_command missing"
    ((errors++))
fi

# Test 14: Cross-repo keycloak-config trigger retained
echo "[14/15] Checking keycloak-config trigger retained..."
if grep -q 'keycloak-config-apply.yml' "$DEV_WORKFLOW"; then
    echo "  ✓ Cross-repo keycloak-config trigger retained"
else
    echo "  ✗ keycloak-config trigger missing"
    ((errors++))
fi

# Test 15: Concurrency group configured
echo "[15/15] Checking concurrency group..."
if grep -q 'concurrency:' "$DEV_WORKFLOW" && \
   grep -q 'group: deploy-keycloak-kamal-do-dev' "$DEV_WORKFLOW"; then
    echo "  ✓ Concurrency group configured"
else
    echo "  ✗ Concurrency group missing or incorrect"
    ((errors++))
fi

echo ""
if [ $errors -eq 0 ]; then
    echo "=== All workflow tests passed ✓ ==="
    exit 0
else
    echo "=== $errors workflow test(s) failed ✗ ==="
    exit 1
fi
