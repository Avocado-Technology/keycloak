#!/usr/bin/env bash
# Test script for Kamal configuration (Phase 2 Gate)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY_YML="$REPO_DIR/config/deploy.yml"
DOCKERFILE="$REPO_DIR/Dockerfile"
SECRETS_TEMPLATE="$REPO_DIR/.kamal/secrets.ci.template"
PREDEPLOY_HOOK="$REPO_DIR/.kamal/hooks/pre-deploy"
GITIGNORE="$REPO_DIR/.gitignore"

echo "=== Testing Kamal Configuration ==="
echo ""

errors=0

# Test 1: deploy.yml exists
echo "[1/10] Checking deploy.yml exists..."
if [ -f "$DEPLOY_YML" ]; then
    echo "  ✓ deploy.yml exists"
else
    echo "  ✗ deploy.yml not found"
    ((errors++))
fi

# Test 2: service name
echo "[2/10] Checking service name..."
if grep -q 'service: avcd-keycloak' "$DEPLOY_YML"; then
    echo "  ✓ service is avcd-keycloak"
else
    echo "  ✗ service should be avcd-keycloak"
    ((errors++))
fi

# Test 3: proxy: false
echo "[3/10] Checking proxy: false..."
if grep -q 'proxy: false' "$DEPLOY_YML"; then
    echo "  ✓ proxy: false is set"
else
    echo "  ✗ proxy: false not found"
    ((errors++))
fi

# Test 4: avcd_edge network
echo "[4/10] Checking avcd_edge network..."
if grep -q 'network: avcd_edge' "$DEPLOY_YML"; then
    echo "  ✓ avcd_edge network configured"
else
    echo "  ✗ avcd_edge network not found"
    ((errors++))
fi

# Test 5: KC_PROXY_HEADERS=xforwarded in env.clear
echo "[5/10] Checking KC_PROXY_HEADERS=xforwarded..."
if grep -q 'KC_PROXY_HEADERS: xforwarded' "$DEPLOY_YML"; then
    echo "  ✓ KC_PROXY_HEADERS=xforwarded configured"
else
    echo "  ✗ KC_PROXY_HEADERS=xforwarded not found"
    ((errors++))
fi

# Test 6: __KEYCLOAK_HOST__ placeholder in Host rule
echo "[6/10] Checking __KEYCLOAK_HOST__ placeholder..."
if grep -q '__KEYCLOAK_HOST__' "$DEPLOY_YML"; then
    echo "  ✓ __KEYCLOAK_HOST__ placeholder present"
else
    echo "  ✗ __KEYCLOAK_HOST__ placeholder not found"
    ((errors++))
fi

# Test 7: Traefik labels present
echo "[7/10] Checking Traefik labels..."
if grep -q 'traefik.enable: "true"' "$DEPLOY_YML" && \
   grep -q 'traefik.docker.network: avcd_edge' "$DEPLOY_YML"; then
    echo "  ✓ Traefik labels configured"
else
    echo "  ✗ Traefik labels incomplete"
    ((errors++))
fi

# Test 8: Dockerfile pins quay.io/keycloak/keycloak:26.0
echo "[8/10] Checking Dockerfile..."
if [ -f "$DOCKERFILE" ]; then
    if grep -q 'quay.io/keycloak/keycloak:26.0' "$DOCKERFILE"; then
        echo "  ✓ Dockerfile pins quay.io/keycloak/keycloak:26.0"
    else
        echo "  ✗ Dockerfile does not pin correct image"
        ((errors++))
    fi
else
    echo "  ✗ Dockerfile not found"
    ((errors++))
fi

# Test 9: secrets.ci.template exists and has required exports
echo "[9/10] Checking secrets.ci.template..."
if [ -f "$SECRETS_TEMPLATE" ]; then
    if grep -q 'KC_DB_URL' "$SECRETS_TEMPLATE" && \
       grep -q 'export_dotenv_file' "$SECRETS_TEMPLATE" && \
       grep -q 'python3' "$SECRETS_TEMPLATE"; then
        echo "  ✓ secrets.ci.template uses bulk export + python parse"
    else
        echo "  ✗ secrets.ci.template missing required exports"
        ((errors++))
    fi
else
    echo "  ✗ secrets.ci.template not found"
    ((errors++))
fi

# Test 10: pre-deploy hook exists and is executable
echo "[10/10] Checking pre-deploy hook..."
if [ -f "$PREDEPLOY_HOOK" ]; then
    if [ -x "$PREDEPLOY_HOOK" ]; then
        if grep -q 'avcd_edge' "$PREDEPLOY_HOOK"; then
            echo "  ✓ pre-deploy hook exists, executable, and handles avcd_edge"
        else
            echo "  ✗ pre-deploy hook missing avcd_edge reference"
            ((errors++))
        fi
    else
        echo "  ✗ pre-deploy hook not executable"
        ((errors++))
    fi
else
    echo "  ✗ pre-deploy hook not found"
    ((errors++))
fi

# Test 11: .gitignore includes .kamal/secrets
echo "[11/14] Checking .gitignore for .kamal/secrets..."
if grep -q '.kamal/secrets' "$GITIGNORE"; then
    echo "  ✓ .gitignore excludes .kamal/secrets"
else
    echo "  ✗ .gitignore should exclude .kamal/secrets"
    ((errors++))
fi

# Test 12: Docker health uses bash TCP probe on port 9000 (not curl on 8080)
echo "[12/14] Checking Docker health-cmd (bash :9000, no curl)..."
if grep -q 'health-cmd' "$DEPLOY_YML" && \
   ! grep -q 'curl' "$DEPLOY_YML" && \
   grep -q '/dev/tcp/127.0.0.1/9000' "$DEPLOY_YML" && \
   grep -q '/health/ready' "$DEPLOY_YML"; then
    echo "  ✓ health-cmd uses bash TCP probe on port 9000"
else
    echo "  ✗ health-cmd should use bash /dev/tcp on 9000 without curl"
    ((errors++))
fi

# Test 13: KC_HEALTH_ENABLED present
echo "[13/14] Checking KC_HEALTH_ENABLED..."
if grep -q 'KC_HEALTH_ENABLED' "$DEPLOY_YML"; then
    echo "  ✓ KC_HEALTH_ENABLED configured"
else
    echo "  ✗ KC_HEALTH_ENABLED not found"
    ((errors++))
fi

# Test 14: builder arch for pre-built quay image
echo "[14/15] Checking builder arch..."
if grep -q 'builder:' "$DEPLOY_YML" && grep -q 'arch: amd64' "$DEPLOY_YML"; then
    echo "  ✓ builder arch amd64 configured"
else
    echo "  ✗ builder arch amd64 required for pre-built image"
    ((errors++))
fi

# Test 15: deploy_timeout exceeds Docker health worst-case (240s)
echo "[15/15] Checking deploy_timeout..."
if grep -q 'deploy_timeout: 210' "$DEPLOY_YML"; then
    echo "  ✓ deploy_timeout is 210s (aligned with Docker health budget)"
else
    echo "  ✗ deploy_timeout should be 210"
    ((errors++))
fi

echo ""
if [ $errors -eq 0 ]; then
    echo "=== All tests passed ✓ ==="
    exit 0
else
    echo "=== $errors test(s) failed ✗ ==="
    exit 1
fi
