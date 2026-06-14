#!/usr/bin/env bash
# Remove corrupted avcd-conta-azul-api from Keycloak + Pulumi state so the next pulumi up recreates it.
# Preserves RandomPassword in state — client secret in Infisical stays valid after recreate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULUMI_DIR="${ROOT}/pulumi"
cd "${PULUMI_DIR}"

STACK="${PULUMI_STACK:-keycloak-config}"
REALM_NAME="${KEYCLOAK_REALM:-avcd}"
CLIENT_ID="${CONTA_AZUL_API_CLIENT_ID:-avcd-conta-azul-api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-$(pulumi config get keycloakUrl --stack "${STACK}" 2>/dev/null || true)}"
ADMIN_USER="${KEYCLOAK_ADMIN_USERNAME:-admin}"

: "${PULUMI_CONFIG_PASSPHRASE:?PULUMI_CONFIG_PASSPHRASE required}"
: "${KEYCLOAK_URL:?KEYCLOAK_URL required}"

pulumi stack select "${STACK}"

if [[ -z "${KEYCLOAK_ADMIN_PASSWORD:-}" ]]; then
  INFISICAL_API_URL="${INFISICAL_API_URL:-https://secrets.avcd.ai/api}"
  INFISICAL_HOST="${INFISICAL_HOST:-${INFISICAL_API_URL%/api}}"
  INFISICAL_ENV="${INFISICAL_ENV:-prod}"
  INFISICAL_SECRET_PATH="${INFISICAL_SECRET_PATH:-/keycloak}"
  : "${INFISICAL_INFRA_PROJECT_ID:?INFISICAL_INFRA_PROJECT_ID required when KEYCLOAK_ADMIN_PASSWORD unset}"
  if [[ -z "${INFISICAL_TOKEN:-}" ]]; then
    : "${INFISICAL_CLIENT_ID:?INFISICAL_CLIENT_ID required}"
    : "${INFISICAL_CLIENT_SECRET:?INFISICAL_CLIENT_SECRET required}"
    export INFISICAL_TOKEN="$(
      infisical login --method=universal-auth \
        --client-id="${INFISICAL_CLIENT_ID}" \
        --client-secret="${INFISICAL_CLIENT_SECRET}" \
        --domain="${INFISICAL_HOST}" --silent --plain
    )"
  fi
  TMP_ENV="$(mktemp)"
  trap 'rm -f "${TMP_ENV}"' RETURN
  infisical export --env="${INFISICAL_ENV}" --path="${INFISICAL_SECRET_PATH}" \
    --projectId="${INFISICAL_INFRA_PROJECT_ID}" --token="${INFISICAL_TOKEN}" \
    --format=dotenv --domain="${INFISICAL_HOST}" --silent > "${TMP_ENV}"
  # shellcheck disable=SC1090
  source "${TMP_ENV}"
fi

: "${KEYCLOAK_ADMIN_PASSWORD:?KEYCLOAK_ADMIN_PASSWORD required}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required" >&2
  exit 1
fi

kc_token() {
  curl -sf -X POST "${KEYCLOAK_URL%/}/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=${ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" | jq -r .access_token
}

KC_TOKEN="$(kc_token)"
CLIENT_INTERNAL_ID="$(curl -sf -H "Authorization: Bearer ${KC_TOKEN}" \
  "${KEYCLOAK_URL%/}/admin/realms/${REALM_NAME}/clients?clientId=${CLIENT_ID}" \
  | jq -r '.[0].id // empty')"

if [[ -n "${CLIENT_INTERNAL_ID}" ]]; then
  echo "Deleting Keycloak client ${CLIENT_ID} (${CLIENT_INTERNAL_ID})"
  curl -sf -X DELETE -H "Authorization: Bearer ${KC_TOKEN}" \
    "${KEYCLOAK_URL%/}/admin/realms/${REALM_NAME}/clients/${CLIENT_INTERNAL_ID}"
  echo "✓ Deleted Keycloak client"
else
  echo "○ Keycloak client ${CLIENT_ID} not found (already deleted)"
fi

URN_FILE="$(mktemp)"
trap 'rm -f "${URN_FILE}"' RETURN
pulumi stack --show-urns --stack "${STACK}" 2>/dev/null | grep -E '^urn:' > "${URN_FILE}" || true

delete_state_if_present() {
  local logical_name="$1"
  local urn
  urn="$(awk -v n="${logical_name}" '$0 ~ ("::" n "$") {print $1; exit}' "${URN_FILE}")"
  if [[ -z "${urn}" ]]; then
    echo "○ not in state: ${logical_name}"
    return 0
  fi
  echo "Removing from Pulumi state: ${urn}"
  pulumi state delete "${urn}" --yes --stack "${STACK}"
}

delete_state_if_present "avcd-client-conta-azul-api-default-scopes"
delete_state_if_present "::avcd-client-conta-azul-api\$"

echo "✓ Ready for pulumi up to recreate ${CLIENT_ID}"
