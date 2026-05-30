#!/usr/bin/env bash
# Export the avcd realm from a running local Keycloak instance.
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
ADMIN="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:?set KEYCLOAK_ADMIN_PASSWORD in .env}"
OUT="${ROOT}/config/avcd-realm.json"

echo "Exporting realm '${REALM}' from ${KEYCLOAK_URL}..."

TOKEN="$(curl -sf -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN}" \
  -d "password=${ADMIN_PASSWORD}" \
  | jq -r '.access_token')"

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "Failed to obtain admin token" >&2
  exit 1
fi

curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/partial-export?exportClients=true&exportGroupsAndRoles=true" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -o "${OUT}.tmp"

jq '.' "${OUT}.tmp" > "${OUT}"
rm "${OUT}.tmp"

echo "Wrote ${OUT}"
echo "Review diff, remove secrets if any were exported, then commit."
