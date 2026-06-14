#!/usr/bin/env bash
# Return 0 when avcd-conta-azul-api client_credentials works; 1 otherwise.
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth.avcd.ai}"
REALM_NAME="${KEYCLOAK_REALM:-avcd}"
CLIENT_ID="${CONTA_AZUL_API_CLIENT_ID:-avcd-conta-azul-api}"

: "${KEYCLOAK_CLIENT_SECRET:?KEYCLOAK_CLIENT_SECRET required}"

RESP="$(curl -sS -X POST "${KEYCLOAK_URL%/}/realms/${REALM_NAME}/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${KEYCLOAK_CLIENT_SECRET}")"

if echo "${RESP}" | jq -e '.access_token | length > 0' >/dev/null 2>&1; then
  echo "✓ ${CLIENT_ID} client_credentials OK"
  exit 0
fi

echo "::warning::${CLIENT_ID} client_credentials failed: ${RESP}" >&2
exit 1
