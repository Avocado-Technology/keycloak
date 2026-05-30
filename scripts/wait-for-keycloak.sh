#!/usr/bin/env bash
# Poll Keycloak until the avcd realm is ready for OIDC requests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="${KEYCLOAK_REALM:-avcd}"
TIMEOUT_SECONDS="${KEYCLOAK_WAIT_TIMEOUT:-180}"
INTERVAL_SECONDS="${KEYCLOAK_WAIT_INTERVAL:-5}"

deadline=$((SECONDS + TIMEOUT_SECONDS))

echo "Waiting for Keycloak at ${KEYCLOAK_URL} (realm: ${REALM}, timeout: ${TIMEOUT_SECONDS}s)..."

while (( SECONDS < deadline )); do
  if curl -sf "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration" >/dev/null 2>&1; then
    echo "Keycloak is ready."
    exit 0
  fi
  sleep "${INTERVAL_SECONDS}"
done

echo "Timed out after ${TIMEOUT_SECONDS}s waiting for Keycloak realm '${REALM}'." >&2
exit 1
