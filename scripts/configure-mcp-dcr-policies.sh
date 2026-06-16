#!/usr/bin/env bash
# Allow Claude/Cursor MCP OAuth Dynamic Client Registration on realm avcd.
#
# Claude connectors POST to Keycloak's registration_endpoint (RFC 7591). Two default
# anonymous policies block DCR:
#   1. Trusted Hosts — "Host not trusted" (HTTP 403)
#   2. Allowed Client Scopes — "Requested scope '' not trusted" when Claude sends
#      an empty scope field in the DCR payload
#
# Also adds avcd-subject + avcd-mcp-audience to realm default client scopes so
# dynamically registered MCP clients receive tokens with the MCP resource audience.
#
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
if [[ "${HTTP_CODE}" != "204" ]]; then
  echo "[mcp-dcr] PUT Trusted Hosts failed HTTP ${HTTP_CODE}" >&2
  cat /tmp/kc-trusted-hosts-response.json >&2
  exit 1
fi

echo "[mcp-dcr] Trusted Hosts updated (host-sending-registration-request-must-match=false)"

ALLOWED_SCOPES=(
  "openid"
  "role_list"
  "saml_organization"
  "profile"
  "email"
  "roles"
  "web-origins"
  "acr"
  "basic"
  "offline_access"
  "address"
  "phone"
  "microprofile-jwt"
  "organization"
  "avcd-subject"
  "avcd-mcp-audience"
  "avcd-api-audience"
  "avcd-conta-azul-audience"
  "avcd-conta-azul-yoga-audience"
  "avcd-api-gateway-audience"
  "claudeai"
)

echo "[mcp-dcr] Updating Allowed Client Scopes anonymous registration policy..."

SCOPE_COMPONENT="$(echo "${COMPONENTS}" | jq -c '.[] | select(.name=="Allowed Client Scopes" and .subType=="anonymous")' | head -1)"

if [[ -z "${SCOPE_COMPONENT}" || "${SCOPE_COMPONENT}" == "null" ]]; then
  echo "[mcp-dcr] No Allowed Client Scopes (anonymous) policy found — skipping" >&2
else
  ALLOWED_SCOPES_JSON="$(printf '%s\n' "${ALLOWED_SCOPES[@]}" | jq -R . | jq -s .)"
  SCOPE_PAYLOAD="$(echo "${SCOPE_COMPONENT}" | jq \
    --argjson allowedScopes "${ALLOWED_SCOPES_JSON}" \
    '.config["allow-default-scopes"] = ["true"]
     | .config["allowed-client-scopes"] = $allowedScopes')"
  SCOPE_COMPONENT_ID="$(echo "${SCOPE_COMPONENT}" | jq -r '.id')"

  SCOPE_HTTP_CODE="$(
    curl -sS -o /tmp/kc-allowed-scopes-response.json -w '%{http_code}' \
      -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${SCOPE_COMPONENT_ID}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${SCOPE_PAYLOAD}"
  )"
  if [[ "${SCOPE_HTTP_CODE}" != "204" ]]; then
    echo "[mcp-dcr] PUT Allowed Client Scopes failed HTTP ${SCOPE_HTTP_CODE}" >&2
    cat /tmp/kc-allowed-scopes-response.json >&2
    exit 1
  fi
  echo "[mcp-dcr] Allowed Client Scopes updated (empty scope in DCR payload allowed)"
fi

DEFAULT_SCOPE_NAMES=(avcd-subject avcd-mcp-audience)
for scope_name in "${DEFAULT_SCOPE_NAMES[@]}"; do
  SCOPE_ID="$(
    curl -sf "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" \
      -H "Authorization: Bearer ${TOKEN}" \
      | jq -r ".[] | select(.name==\"${scope_name}\") | .id"
  )"
  if [[ -z "${SCOPE_ID}" || "${SCOPE_ID}" == "null" ]]; then
    echo "[mcp-dcr] Client scope ${scope_name} not found — skipping default assignment" >&2
    continue
  fi
  DEFAULT_HTTP_CODE="$(
    curl -sS -o /tmp/kc-default-scope-response.json -w '%{http_code}' \
      -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/default-default-client-scopes/${SCOPE_ID}" \
      -H "Authorization: Bearer ${TOKEN}"
  )"
  if [[ "${DEFAULT_HTTP_CODE}" != "204" && "${DEFAULT_HTTP_CODE}" != "409" ]]; then
    echo "[mcp-dcr] Failed to add default scope ${scope_name} HTTP ${DEFAULT_HTTP_CODE}" >&2
    cat /tmp/kc-default-scope-response.json >&2
    exit 1
  fi
  echo "[mcp-dcr] Default client scope ${scope_name} ensured"
done

# ---------------------------------------------------------------------------
# Fix: Keycloak does NOT inherit realm default scopes for DCR-registered
# clients. Only `basic` gets assigned. Tokens therefore lack
# aud=https://dev.avocado.tech/mcp, and Apollo MCP rejects them.
#
# Strategy: Find any remaining DCR-registered clients (those with
# only `basic` as default scope and no `avcd-mcp-audience`) and patch them.
# This is idempotent; existing correctly-patched clients are skipped.
# ---------------------------------------------------------------------------
echo "[mcp-dcr] Patching existing DCR clients: adding avcd-mcp-audience default scope..."

MCP_AUD_SCOPE_ID="$(
  curl -sf "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" \
    -H "Authorization: Bearer ${TOKEN}" \
    | jq -r '.[] | select(.name=="avcd-mcp-audience") | .id'
)"

  if [[ -z "${MCP_AUD_SCOPE_ID}" || "${MCP_AUD_SCOPE_ID}" == "null" ]]; then
  echo "[mcp-dcr] avcd-mcp-audience scope not found — skipping client patch" >&2
else
  SUBJECT_SCOPE_ID="$(
    curl -sf "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" \
      -H "Authorization: Bearer ${TOKEN}" \
      | jq -r '.[] | select(.name=="avcd-subject") | .id'
  )"
  # Get all clients that were registered via DCR (public clients with no serviceAccountsEnabled)
  # and are missing the avcd-mcp-audience default scope.
  ALL_CLIENTS="$(curl -sf "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?max=200" \
    -H "Authorization: Bearer ${TOKEN}")"

  PATCHED=0
  SKIPPED=0
  while IFS= read -r client_id; do
    # Check current default scopes
    CURRENT_SCOPES="$(curl -sf "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${client_id}/default-client-scopes" \
      -H "Authorization: Bearer ${TOKEN}" | jq -r '.[].name')"
    if echo "${CURRENT_SCOPES}" | grep -q "avcd-mcp-audience"; then
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    # Patch: add avcd-mcp-audience (+ avcd-subject when available)
    PATCH_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
      -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${client_id}/default-client-scopes/${MCP_AUD_SCOPE_ID}" \
      -H "Authorization: Bearer ${TOKEN}")"
    if [[ -n "${SUBJECT_SCOPE_ID}" && "${SUBJECT_SCOPE_ID}" != "null" ]]; then
      curl -sS -o /dev/null \
        -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${client_id}/default-client-scopes/${SUBJECT_SCOPE_ID}" \
        -H "Authorization: Bearer ${TOKEN}" || true
    fi
    if [[ "${PATCH_CODE}" == "204" || "${PATCH_CODE}" == "409" ]]; then
      PATCHED=$((PATCHED + 1))
    fi
  done < <(echo "${ALL_CLIENTS}" | jq -r '.[] | select(.publicClient == true and .serviceAccountsEnabled == false) | .id')

  echo "[mcp-dcr] DCR client patch: ${PATCHED} patched, ${SKIPPED} already had scope"
fi

echo "[mcp-dcr] Verifying anonymous DCR (Claude-like payload with empty scope)..."
DCR_CODE="$(
  curl -sS -o /tmp/kc-dcr-response.json -w '%{http_code}' \
    -X POST "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
    -H "Content-Type: application/json" \
    -d '{
      "client_name": "mcp-dcr-smoke",
      "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
      "token_endpoint_auth_method": "none",
      "grant_types": ["authorization_code", "refresh_token"],
      "response_types": ["code"],
      "scope": ""
    }'
)"

if [[ "${DCR_CODE}" == "201" || "${DCR_CODE}" == "200" ]]; then
  CLIENT_ID="$(jq -r '.client_id // empty' /tmp/kc-dcr-response.json)"
  echo "[mcp-dcr] DCR smoke OK empty scope (client_id=${CLIENT_ID})"
  if [[ -n "${CLIENT_ID}" ]]; then
    curl -sf -X DELETE \
      "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" \
      -H "Authorization: Bearer ${TOKEN}" >/dev/null || true
  fi
else
  echo "[mcp-dcr] DCR smoke failed empty scope HTTP ${DCR_CODE}" >&2
  cat /tmp/kc-dcr-response.json >&2
  exit 1
fi

echo "[mcp-dcr] Verifying Claude default DCR scope (claudeai)..."
CLAUDE_DCR_CODE="$(
  curl -sS -o /tmp/kc-dcr-claudeai-response.json -w '%{http_code}' \
    -X POST "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
    -H "Content-Type: application/json" \
    -d '{
      "client_name": "claudeai",
      "redirect_uris": ["https://claude.ai/api/mcp/auth_callback", "https://claude.com/api/mcp/auth_callback"],
      "token_endpoint_auth_method": "none",
      "grant_types": ["authorization_code", "refresh_token"],
      "response_types": ["code"],
      "scope": "claudeai"
    }'
)"

if [[ "${CLAUDE_DCR_CODE}" == "201" || "${CLAUDE_DCR_CODE}" == "200" ]]; then
  CLIENT_ID="$(jq -r '.client_id // empty' /tmp/kc-dcr-claudeai-response.json)"
  echo "[mcp-dcr] DCR smoke OK claudeai scope (client_id=${CLIENT_ID})"
  if [[ -n "${CLIENT_ID}" ]]; then
    curl -sf -X DELETE \
      "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" \
      -H "Authorization: Bearer ${TOKEN}" >/dev/null || true
  fi
else
  echo "[mcp-dcr] DCR smoke failed claudeai scope HTTP ${CLAUDE_DCR_CODE}" >&2
  cat /tmp/kc-dcr-claudeai-response.json >&2
  exit 1
fi

echo "[mcp-dcr] Verifying DCR with openid scope (critical for Claude)..."
OPENID_DCR_CODE="$(
  curl -sS -o /tmp/kc-dcr-openid-response.json -w '%{http_code}' \
    -X POST "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
    -H "Content-Type: application/json" \
    -d '{
      "client_name": "mcp-dcr-openid-smoke",
      "redirect_uris": ["https://claude.ai/api/mcp/auth_callback"],
      "token_endpoint_auth_method": "none",
      "grant_types": ["authorization_code", "refresh_token"],
      "response_types": ["code"],
      "scope": "openid profile email offline_access"
    }'
)"

if [[ "${OPENID_DCR_CODE}" == "201" || "${OPENID_DCR_CODE}" == "200" ]]; then
  CLIENT_ID="$(jq -r '.client_id // empty' /tmp/kc-dcr-openid-response.json)"
  echo "[mcp-dcr] DCR smoke OK openid scope (client_id=${CLIENT_ID})"
  if [[ -n "${CLIENT_ID}" ]]; then
    curl -sf -X DELETE \
      "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" \
      -H "Authorization: Bearer ${TOKEN}" >/dev/null || true
  fi
else
  echo "[mcp-dcr] DCR smoke failed openid scope HTTP ${OPENID_DCR_CODE}" >&2
  cat /tmp/kc-dcr-openid-response.json >&2
  exit 1
fi

echo "[mcp-dcr] Done"
