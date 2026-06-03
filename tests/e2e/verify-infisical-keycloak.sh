#!/usr/bin/env bash
# Verify Infisical /keycloak prod secrets exist (catalog from avcd-keycloak/secrets stack).
#
# Usage:
#   bash tests/e2e/verify-infisical-keycloak.sh
set -euo pipefail

PASS=0
FAIL=0
check() {
  local label=$1
  shift
  if "$@" &>/dev/null; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label"
    FAIL=$((FAIL + 1))
  fi
}

INFISICAL_HOST="${INFISICAL_HOST:-https://secrets.avcd.ai}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_ID="${INFISICAL_INFRA_PROJECT_ID:-db036f0e-7452-4e17-9573-e5471b45d65f}"
ENV_SLUG="${INFISICAL_ENV:-prod}"
SECRET_PATH="${INFISICAL_SECRET_PATH:-/keycloak}"

if [[ -z "${INFISICAL_TOKEN:-}" ]]; then
  INFISICAL_TOKEN="$("${ROOT}/tests/e2e/helpers/get-infisical-token.sh")"
fi
export INFISICAL_TOKEN

REQUIRED_KEYS=(
  KC_DB_URL
  KC_DB_USERNAME
  KC_DB_PASSWORD
  KEYCLOAK_ADMIN_PASSWORD
  KEYCLOAK_HOST
  DO_DEPLOY_HOST
  KEYCLOAK_IMAGE_TAG
  KEYCLOAK_POSTGRES_BOOTSTRAP_URI
)

echo "=== Keycloak Infisical /keycloak verification ==="

EXPORT="$(infisical export --env="${ENV_SLUG}" --path="${SECRET_PATH}" \
  --projectId="${PROJECT_ID}" --token="${INFISICAL_TOKEN}" \
  --format=dotenv --domain="${INFISICAL_HOST}" --silent)"

for k in "${REQUIRED_KEYS[@]}"; do
  check "secret ${k}" bash -c "echo \"${EXPORT}\" | grep -q '^${k}='"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]] || exit 1
