#!/usr/bin/env bash
# E2E: Keycloak Google IdP — Google broker configured and auth URL reachable.
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
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:?set KEYCLOAK_ADMIN_PASSWORD in .env}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:?set GOOGLE_CLIENT_ID in .env}"
WEB_CLIENT_ID="${KEYCLOAK_WEB_CLIENT_ID:-avcd-web}"
WEB_REDIRECT_URI="${KEYCLOAK_WEB_REDIRECT_URI:-http://localhost:3000/api/auth/callback}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq

echo "Step 1/3: Admin API — Google IdP exists and enabled"
ADMIN_TOKEN="$(
  curl -sf -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    | jq -r '.access_token'
)"
if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
  echo "Failed to obtain Keycloak admin token" >&2
  exit 1
fi

IDP_JSON="$(
  curl -sf \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/identity-provider/instances/google"
)"
echo "$IDP_JSON" | jq -e '.enabled == true and .providerId == "google"' >/dev/null
CONFIGURED_CLIENT_ID="$(echo "$IDP_JSON" | jq -r '.config.clientId // empty')"
if [[ "$CONFIGURED_CLIENT_ID" != "$GOOGLE_CLIENT_ID" ]]; then
  echo "Google IdP clientId mismatch: got '${CONFIGURED_CLIENT_ID}', expected '${GOOGLE_CLIENT_ID}'" >&2
  exit 1
fi
if [[ "$CONFIGURED_CLIENT_ID" == "REPLACE_VIA_CONFIGURE_SCRIPT" ]]; then
  echo "Google IdP still uses placeholder clientId — run configure-google-idp.sh" >&2
  exit 1
fi
echo "  Google IdP enabled with clientId: ${CONFIGURED_CLIENT_ID}"

echo "Step 2/3: Authorization URL redirects toward Google broker"
AUTH_URL="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth"
AUTH_QUERY="client_id=${WEB_CLIENT_ID}&response_type=code&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${WEB_REDIRECT_URI}', safe=''))")&scope=openid&kc_idp_hint=google"
LOCATION="$(
  curl -sI "${AUTH_URL}?${AUTH_QUERY}" \
    | tr -d '\r' \
    | awk -F': ' 'tolower($1)=="location"{print $2; exit}'
)"
if [[ -z "$LOCATION" ]]; then
  echo "Expected 302 Location header from authorization endpoint" >&2
  exit 1
fi
if [[ "$LOCATION" != *"accounts.google.com"* && "$LOCATION" != *"broker/google"* && "$LOCATION" != *"google"* ]]; then
  echo "Unexpected authorization redirect: ${LOCATION}" >&2
  exit 1
fi
echo "  authorization redirect ok"

echo "Step 3/3: Regression — password grant still works"
"${ROOT}/scripts/e2e-local-validation.sh"

echo "Google IdP E2E PASS"
