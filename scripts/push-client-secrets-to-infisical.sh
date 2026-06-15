#!/usr/bin/env bash
# Read confidential client secrets from Keycloak Admin API and push to Infisical app projects.
# Replaces the former pulumi-infra web-secrets / keycloak-config stack output chain.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP_FILE="${ROOT}/config/infisical-client-secrets.json"
REALM="${KEYCLOAK_REALM:-avcd}"

# shellcheck disable=SC1091
source "${ROOT}/scripts/prepare-keycloak-config-env.sh"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq required" >&2
  exit 1
}
command -v infisical >/dev/null 2>&1 || {
  echo "ERROR: infisical CLI required" >&2
  exit 1
}

INFISICAL_API_URL="${INFISICAL_API_URL:-https://secrets.avcd.ai/api}"
INFISICAL_HOST="${INFISICAL_HOST:-${INFISICAL_API_URL%/api}}"

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

kc_admin_token() {
  local resp
  resp="$(curl -sS -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_USER}" \
    -d "password=${KEYCLOAK_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli")"
  echo "${resp}" | jq -r '.access_token // empty'
}

kc_client_uuid() {
  local token="$1" client_id="$2"
  curl -sS \
    -H "Authorization: Bearer ${token}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${client_id}" \
    | jq -r '.[0].id // empty'
}

kc_client_secret_value() {
  local token="$1" uuid="$2"
  curl -sS \
    -H "Authorization: Bearer ${token}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${uuid}/client-secret" \
    | jq -r '.value // empty'
}

push_infisical_secret() {
  local project_id="$1" env_slug="$2" folder_path="$3" key="$4" value="$5"
  infisical secrets set "${key}=${value}" \
    --env="${env_slug}" \
    --path="${folder_path}" \
    --projectId="${project_id}" \
    --token="${INFISICAL_TOKEN}" \
    --domain="${INFISICAL_HOST}" \
    --silent
  echo "✓ Infisical ${env_slug}${folder_path} ${key} (client push)"
}

TOKEN="$(kc_admin_token)"
[[ -n "${TOKEN}" ]] || {
  echo "ERROR: Keycloak admin token request failed" >&2
  exit 1
}

[[ -f "${MAP_FILE}" ]] || {
  echo "ERROR: missing ${MAP_FILE}" >&2
  exit 1
}

while IFS= read -r entry; do
  client_id="$(echo "${entry}" | jq -r '.clientId')"
  project_id="$(echo "${entry}" | jq -r '.infisicalProjectId // empty')"
  project_id_env="$(echo "${entry}" | jq -r '.infisicalProjectIdEnv // empty')"
  env_slug="$(echo "${entry}" | jq -r '.infisicalEnv')"
  folder_path="$(echo "${entry}" | jq -r '.infisicalPath')"
  secret_key="$(echo "${entry}" | jq -r '.secretKey')"

  if [[ -z "${project_id}" && -n "${project_id_env}" ]]; then
    project_id="${!project_id_env:-}"
  fi
  if [[ -z "${project_id}" ]]; then
    echo "ℹ Skip ${client_id} — no Infisical project id configured"
    continue
  fi

  uuid="$(kc_client_uuid "${TOKEN}" "${client_id}")"
  [[ -n "${uuid}" ]] || {
    echo "ERROR: client ${client_id} not found in realm ${REALM}" >&2
    exit 1
  }

  secret="$(kc_client_secret_value "${TOKEN}" "${uuid}")"
  [[ -n "${secret}" ]] || {
    echo "ERROR: empty secret for ${client_id}" >&2
    exit 1
  }

  push_infisical_secret "${project_id}" "${env_slug}" "${folder_path}" "${secret_key}" "${secret}"
done < <(jq -c '.[]' "${MAP_FILE}")

echo "✓ Client secrets pushed to Infisical"
