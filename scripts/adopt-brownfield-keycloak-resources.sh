#!/usr/bin/env bash
# Import Keycloak resources that already exist on auth.avcd.ai but are missing from
# keycloak-config stack state (avoids 409 Conflict on pulumi up).
#
# Run after adopt-keycloak-config-state.sh and set-keycloak-config-secrets.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULUMI_DIR="${ROOT}/pulumi"
cd "${PULUMI_DIR}"

STACK="${PULUMI_STACK:-keycloak-config}"
REALM_NAME="${KEYCLOAK_REALM:-avcd}"
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

URN_FILE="$(mktemp)"
trap 'rm -f "${URN_FILE}"' RETURN
pulumi stack --show-urns --stack "${STACK}" 2>/dev/null \
  | grep -oE 'urn:pulumi:[^[:space:]]+' > "${URN_FILE}" || true
PARENT_URN="$(grep 'KeycloakConfig::avcd' "${URN_FILE}" | head -1 || true)"
KEYCLOAK_PROVIDER_URN="$(grep 'pulumi:providers:keycloak::keycloak' "${URN_FILE}" | head -1 || true)"
STATE_URNS="$(cat "${URN_FILE}")"

if [[ -z "${PARENT_URN}" ]]; then
  echo "Error: KeycloakConfig parent URN not found in stack ${STACK}" >&2
  exit 1
fi

if [[ -z "${KEYCLOAK_PROVIDER_URN}" ]]; then
  echo "Error: keycloak provider URN not found in stack ${STACK}" >&2
  exit 1
fi

in_state() {
  local logical_name="$1"
  grep -q "::${logical_name}\$" <<<"${STATE_URNS}"
}

kc_token() {
  curl -sf -X POST "${KEYCLOAK_URL%/}/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=${ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" | jq -r .access_token
}

kc_get() {
  local path="$1"
  curl -sf -H "Authorization: Bearer ${KC_TOKEN}" \
    "${KEYCLOAK_URL%/}/admin${path}"
}

import_resource() {
  local pulumi_type="$1"
  local logical_name="$2"
  local import_id="$3"

  if in_state "${logical_name}"; then
    echo "✓ already in state: ${logical_name}"
    return 0
  fi

  echo "Importing ${logical_name} (${import_id})"
  if ! pulumi import "${pulumi_type}" "${logical_name}" "${import_id}" \
    --parent "${PARENT_URN}" --provider "${KEYCLOAK_PROVIDER_URN}" --yes --stack "${STACK}"; then
    echo "::error::Import failed for ${logical_name}" >&2
    exit 1
  fi
}

KC_TOKEN="$(kc_token)"
REALM_ID="$(kc_get "/realms/${REALM_NAME}" | jq -r .id)"
CLIENT_SCOPES_JSON="$(kc_get "/realms/${REALM_NAME}/client-scopes")"

scope_id_by_name() {
  local name="$1"
  jq -r --arg n "${name}" '[.[] | select(.name == $n) | .id][0] // empty' <<<"${CLIENT_SCOPES_JSON}"
}

mapper_id_by_name() {
  local scope_id="$1"
  local mapper_name="$2"
  kc_get "/realms/${REALM_NAME}/client-scopes/${scope_id}/protocol-mappers/models" \
    | jq -r --arg n "${mapper_name}" '[.[] | select(.name == $n) | .id][0] // empty'
}

client_internal_id() {
  local client_id="$1"
  kc_get "/realms/${REALM_NAME}/clients" \
    | jq -r --arg c "${client_id}" '[.[] | select(.clientId == $c) | .id][0] // empty'
}

import_scope_and_mapper() {
  local scope_name="$1"
  local scope_logical="$2"
  local mapper_logical="$3"

  local scope_id
  scope_id="$(scope_id_by_name "${scope_name}")"
  if [[ -z "${scope_id}" || "${scope_id}" == "null" ]]; then
    echo "○ scope not in Keycloak yet: ${scope_name} (pulumi up will create)"
    return 0
  fi

  import_resource "keycloak:openid/clientScope:ClientScope" \
    "${scope_logical}" "${REALM_ID}/${scope_id}"

  local mapper_id
  mapper_id="$(mapper_id_by_name "${scope_id}" "${scope_name}-mapper")"
  if [[ -n "${mapper_id}" && "${mapper_id}" != "null" ]]; then
    import_resource "keycloak:openid/audienceProtocolMapper:AudienceProtocolMapper" \
      "${mapper_logical}" "${REALM_ID}/client-scope/${scope_id}/${mapper_id}"
  fi
}

echo "Brownfield adopt on ${KEYCLOAK_URL} realm=${REALM_NAME} stack=${STACK}"

import_scope_and_mapper "avcd-conta-azul-audience" \
  "avcd-scope-conta-azul-audience" "avcd-mapper-conta-azul-audience"

import_scope_and_mapper "avcd-conta-azul-yoga-audience" \
  "avcd-scope-conta-azul-yoga-audience" "avcd-mapper-conta-azul-yoga-audience"

import_scope_and_mapper "avcd-api-gateway-audience" \
  "avcd-scope-api-gateway-audience" "avcd-mapper-api-gateway-audience"

CONTA_AZUL_CLIENT_ID="$(client_internal_id "avcd-conta-azul-api")"
if [[ -n "${CONTA_AZUL_CLIENT_ID}" && "${CONTA_AZUL_CLIENT_ID}" != "null" ]]; then
  echo "○ skipping M2M client import (managed by Pulumi create/replace; import caused broken client_credentials)"
fi

echo "✓ Brownfield Keycloak resource adopt complete"
