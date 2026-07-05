#!/usr/bin/env bash
# Export env vars for keycloak-config-cli (audiences, client secrets, admin auth).
# Sources Infisical /keycloak when credentials are available; generates stable client
# secrets when not already set in the environment.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Defaults aligned with pulumi/Pulumi.keycloak-config.yaml
export KEYCLOAK_URL="${KEYCLOAK_URL:-https://auth.avcd.ai}"
export KEYCLOAK_USER="${KEYCLOAK_USER:-${KEYCLOAK_ADMIN_USERNAME:-admin}}"
export API_AUDIENCE="${API_AUDIENCE:-https://dev.avcd.ai/api}"
export MCP_AUDIENCE="${MCP_AUDIENCE:-https://dev.avocado.tech/mcp}"
export CONTA_AZUL_AUDIENCE="${CONTA_AZUL_AUDIENCE:-https://dev.avocado.tech/conta-azul-yoga-subgraph}"
export CONTA_AZUL_YOGA_AUDIENCE="${CONTA_AZUL_YOGA_AUDIENCE:-https://dev.avocado.tech/conta-azul-yoga-subgraph}"
export API_GATEWAY_AUDIENCE="${API_GATEWAY_AUDIENCE:-https://dev.avocado.tech/api-gateway}"

generate_secret() {
  openssl rand -base64 24 | tr -d '/+=' | head -c 32
}

ensure_client_secret() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    printf -v "$var_name" '%s' "$(generate_secret)"
    export "$var_name"
    echo "ℹ Generated ${var_name} (not previously set)"
  fi
}

if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

INFISICAL_API_URL="${INFISICAL_API_URL:-https://secrets.avcd.ai/api}"
INFISICAL_HOST="${INFISICAL_HOST:-${INFISICAL_API_URL%/api}}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_SECRET_PATH="${INFISICAL_SECRET_PATH:-/keycloak}"
INFISICAL_INFRA_PROJECT_ID="${INFISICAL_INFRA_PROJECT_ID:-db036f0e-7452-4e17-9573-e5471b45d65f}"
MCP_PROJECT_ID="${INFISICAL_MCP_PROJECT_ID:-891adf21-6a18-4967-be44-ac6e9c9483be}"
MCP_INFISICAL_ENV="${MCP_INFISICAL_ENV:-dev}"

pull_infisical_keycloak() {
  if ! command -v infisical >/dev/null 2>&1; then
    return 0
  fi
  if [[ -z "${INFISICAL_TOKEN:-}" ]]; then
    if [[ -n "${INFISICAL_CLIENT_ID:-}" && -n "${INFISICAL_CLIENT_SECRET:-}" ]]; then
      export INFISICAL_TOKEN="$(
        infisical login --method=universal-auth \
          --client-id="${INFISICAL_CLIENT_ID}" \
          --client-secret="${INFISICAL_CLIENT_SECRET}" \
          --domain="${INFISICAL_HOST}" --silent --plain
      )"
    else
      return 0
    fi
  fi

  local tmp="" mcp_tmp=""
  tmp="$(mktemp)"
  mcp_tmp="$(mktemp)"
  trap '[[ -n "${tmp:-}" ]] && rm -f "${tmp}"; [[ -n "${mcp_tmp:-}" ]] && rm -f "${mcp_tmp}"' RETURN

  if infisical export --env="${INFISICAL_ENV}" --path="${INFISICAL_SECRET_PATH}" \
    --projectId="${INFISICAL_INFRA_PROJECT_ID}" --token="${INFISICAL_TOKEN}" \
    --format=dotenv --domain="${INFISICAL_HOST}" --silent >"${tmp}"; then
    set -a
    # shellcheck disable=SC1090
    source "${tmp}"
    set +a
  fi

  if infisical export --env="${MCP_INFISICAL_ENV}" --path=/conta-azul-mcp \
    --projectId="${MCP_PROJECT_ID}" --token="${INFISICAL_TOKEN}" \
    --format=dotenv --domain="${INFISICAL_HOST}" --silent >"${mcp_tmp}" 2>/dev/null; then
    set -a
    # shellcheck disable=SC1090
    source "${mcp_tmp}"
    set +a
  fi
}

pull_infisical_keycloak

export KEYCLOAK_PASSWORD="${KEYCLOAK_PASSWORD:-${KEYCLOAK_ADMIN_PASSWORD:-}}"

pull_app_secret() {
  local project_id="$1" env_slug="$2" path="$3" key="$4" target_var="$5"
  [[ -n "${!target_var:-}" ]] && return 0
  [[ -z "${INFISICAL_TOKEN:-}" ]] && return 0
  local tmp="" val=""
  tmp="$(mktemp)"
  if infisical export --env="${env_slug}" --path="${path}" \
    --projectId="${project_id}" --token="${INFISICAL_TOKEN}" \
    --format=dotenv --domain="${INFISICAL_HOST}" --silent >"${tmp}" 2>/dev/null; then
    val="$(grep -E "^${key}=" "${tmp}" | head -1 | cut -d= -f2- | tr -d '"' || true)"
    if [[ -n "${val}" ]]; then
      printf -v "$target_var" '%s' "${val}"
      export "$target_var"
    fi
  fi
  [[ -n "${tmp:-}" ]] && rm -f "${tmp}"
}

WEB_PROJECT_ID="${INFISICAL_WEB_PROJECT_ID:-4c32b3c4-fb30-44a2-81bb-2ae4211404a3}"
pull_app_secret "${WEB_PROJECT_ID}" "dev" "/" "KEYCLOAK_CLIENT_SECRET" "AVCD_WEB_CLIENT_SECRET"
pull_app_secret "${MCP_PROJECT_ID}" "${MCP_INFISICAL_ENV}" "/conta-azul-mcp" "KEYCLOAK_CLIENT_SECRET" "AVCD_CONTA_AZUL_API_CLIENT_SECRET"
if [[ -n "${INFISICAL_ODOO_PROJECT_ID:-}" ]]; then
  pull_app_secret "${INFISICAL_ODOO_PROJECT_ID}" "dev" "/odoo" "KEYCLOAK_CLIENT_SECRET" "AVCD_ODOO_CLIENT_SECRET"
fi
if [[ -n "${INFISICAL_AI_PROJECT_ID:-}" ]]; then
  pull_app_secret "${INFISICAL_AI_PROJECT_ID}" "dev" "/" "OPENID_CLIENT_SECRET" "AVCD_AI_CLIENT_SECRET"
fi
if [[ -n "${INFISICAL_FRAPPE_PROJECT_ID:-}" ]]; then
  pull_app_secret "${INFISICAL_FRAPPE_PROJECT_ID}" "dev" "/frappe" "KEYCLOAK_CLIENT_SECRET" "AVCD_FRAPPE_CLIENT_SECRET"
fi

# Explicit overrides (after Infisical pull)
export AVCD_WEB_CLIENT_SECRET="${AVCD_WEB_CLIENT_SECRET:-${KEYCLOAK_CLIENT_SECRET_WEB:-}}"
export AVCD_ODOO_CLIENT_SECRET="${AVCD_ODOO_CLIENT_SECRET:-${KEYCLOAK_CLIENT_SECRET_ODOO:-}}"
export AVCD_AI_CLIENT_SECRET="${AVCD_AI_CLIENT_SECRET:-${KEYCLOAK_CLIENT_SECRET_AI:-}}"
export AVCD_FRAPPE_CLIENT_SECRET="${AVCD_FRAPPE_CLIENT_SECRET:-${KEYCLOAK_CLIENT_SECRET_FRAPPE:-}}"
export AVCD_CONTA_AZUL_API_CLIENT_SECRET="${AVCD_CONTA_AZUL_API_CLIENT_SECRET:-${KEYCLOAK_CLIENT_SECRET:-}}"

ensure_client_secret AVCD_WEB_CLIENT_SECRET
ensure_client_secret AVCD_ODOO_CLIENT_SECRET
ensure_client_secret AVCD_AI_CLIENT_SECRET
ensure_client_secret AVCD_FRAPPE_CLIENT_SECRET
ensure_client_secret AVCD_CONTA_AZUL_API_CLIENT_SECRET

: "${KEYCLOAK_PASSWORD:?KEYCLOAK_PASSWORD or KEYCLOAK_ADMIN_PASSWORD required}"
