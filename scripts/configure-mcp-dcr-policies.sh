#!/usr/bin/env bash
# Allow Claude/Cursor MCP OAuth Dynamic Client Registration on realm avcd.
#
# Claude connectors POST to Keycloak's registration_endpoint (RFC 7591). The default
# "Trusted Hosts" policy rejects those requests with:
#   Policy 'Trusted Hosts' rejected request ... Host not trusted.
#
# Fix: relax host-matching and whitelist MCP client redirect URI hosts.
# Idempotent — safe to re-run after pulumi keycloak-config apply.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_KEYCLOAK_URL="${KEYCLOAK_URL:-}"
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi
if [[ -f "${ROOT}/.env.infisical" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env.infisical"
  set +a
fi

if [[ -n "${CLI_KEYCLOAK_URL}" ]]; then
  KEYCLOAK_URL="${CLI_KEYCLOAK_URL}"
fi
KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth.avcd.ai}"
REALM="${KEYCLOAK_REALM:-avcd}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-${KEYCLOAK_ADMIN_USERNAME:-admin}}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:?set KEYCLOAK_ADMIN_PASSWORD}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq

admin_token() {
  curl -sf -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${KEYCLOAK_ADMIN}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    | jq -r '.access_token'
}

TRUSTED_HOSTS=(
  "localhost"
  "127.0.0.1"
  "claude.ai"
  "claude.com"
  "dev.avocado.tech"
  "dev.avcd.ai"
  "avcd.ai"
)

echo "[mcp-dcr] Updating Trusted Hosts client registration policy on ${KEYCLOAK_URL} realm ${REALM}..."

TOKEN="$(admin_token)"
if [[ -z "${TOKEN}" || "${TOKEN}" == "null" ]]; then
  echo "Failed to obtain Keycloak admin token" >&2
  exit 1
fi

COMPONENTS="$(
  curl -sf "${KEYCLOAK_URL}/admin/realms/${REALM}/components?type=org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy" \
    -H "Authorization: Bearer ${TOKEN}"
)"

COMPONENT="$(echo "${COMPONENTS}" | jq -c '.[] | select(.name=="Trusted Hosts")' | head -1)"

if [[ -z "${COMPONENT}" || "${COMPONENT}" == "null" ]]; then
  echo "[mcp-dcr] No Trusted Hosts policy found — nothing to update" >&2
  exit 0
fi

TRUSTED_HOSTS_JSON="$(printf '%s\n' "${TRUSTED_HOSTS[@]}" | jq -R . | jq -s .)"

PAYLOAD="$(echo "${COMPONENT}" | jq \
  --argjson trustedHosts "${TRUSTED_HOSTS_JSON}" \
  '.config["host-sending-registration-request-must-match"] = ["false"]
   | .config["client-uris-must-match"] = ["true"]
   | .config["trusted-hosts"] = $trustedHosts')"
COMPONENT_ID="$(echo "${COMPONENT}" | jq -r '.id')"

HTTP_CODE="$(
  curl -sS -o /tmp/kc-trusted-hosts-response.json -w '%{http_code}' \
    -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${COMPONENT_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}"
)"
  echo "[mcp-dcr] PUT Trusted Hosts failed HTTP ${HTTP_CODE}" >&2
  cat /tmp/kc-trusted-hosts-response.json >&2
  exit 1
fi

echo "[mcp-dcr] Trusted Hosts updated (host-sending-registration-request-must-match=false)"

echo "[mcp-dcr] Verifying anonymous DCR..."
DCR_CODE="$(
  curl -sS -o /tmp/kc-dcr-response.json -w '%{http_code}' \
    -X POST "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
    -H "Content-Type: application/json" \
    -d '{
      "client_name": "mcp-dcr-smoke",
      "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
      "token_endpoint_auth_method": "none",
      "grant_types": ["authorization_code"],
      "response_types": ["code"]
    }'
)"

if [[ "${DCR_CODE}" == "201" || "${DCR_CODE}" == "200" ]]; then
  CLIENT_ID="$(jq -r '.client_id // empty' /tmp/kc-dcr-response.json)"
  REG_ID="$(jq -r '.registration_access_token // empty' /tmp/kc-dcr-response.json)"
  echo "[mcp-dcr] DCR smoke OK (client_id=${CLIENT_ID})"
  if [[ -n "${CLIENT_ID}" ]]; then
    curl -sf -X DELETE \
      "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" \
      -H "Authorization: Bearer ${TOKEN}" >/dev/null || true
    echo "[mcp-dcr] Cleaned up smoke client ${CLIENT_ID}"
  fi
  unset REG_ID
else
  echo "[mcp-dcr] DCR smoke failed HTTP ${DCR_CODE}" >&2
  cat /tmp/kc-dcr-response.json >&2
  exit 1
fi

echo "[mcp-dcr] Done"
