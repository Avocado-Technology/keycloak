#!/usr/bin/env bash
# Idempotent apply of config/realm-avcd.yaml (+ optional google-idp.yaml) via keycloak-config-cli.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1091
source "${ROOT}/scripts/prepare-keycloak-config-env.sh"

KEYCLOAK_CONFIG_CLI_IMAGE="${KEYCLOAK_CONFIG_CLI_IMAGE:-adorsys/keycloak-config-cli:latest-26.0.0}"

IMPORT_LOCATIONS="/config/realm-avcd.yaml"
if [[ -n "${GOOGLE_CLIENT_ID:-}" && -n "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  IMPORT_LOCATIONS="${IMPORT_LOCATIONS},/config/google-idp.yaml"
  echo "✓ Google IdP enabled (GOOGLE_CLIENT_ID set)"
else
  echo "ℹ Google IdP skipped (GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET unset)"
fi

docker run --rm \
  -e KEYCLOAK_URL \
  -e KEYCLOAK_USER \
  -e KEYCLOAK_PASSWORD \
  -e API_AUDIENCE \
  -e MCP_AUDIENCE \
  -e CONTA_AZUL_AUDIENCE \
  -e CONTA_AZUL_YOGA_AUDIENCE \
  -e API_GATEWAY_AUDIENCE \
  -e AVCD_WEB_CLIENT_SECRET \
  -e AVCD_ODOO_CLIENT_SECRET \
  -e AVCD_AI_CLIENT_SECRET \
  -e AVCD_FRAPPE_CLIENT_SECRET \
  -e AVCD_CONTA_AZUL_API_CLIENT_SECRET \
  -e GOOGLE_CLIENT_ID \
  -e GOOGLE_CLIENT_SECRET \
  -e IMPORT_VAR_SUBSTITUTION_ENABLED=true \
  -v "${ROOT}/config:/config:ro" \
  "${KEYCLOAK_CONFIG_CLI_IMAGE}" \
  --import.files.locations="${IMPORT_LOCATIONS}" \
  --import.managed.client=no-delete \
  --import.managed.client-scope=no-delete \
  --import.managed.client-scope-mapping=no-delete \
  --import.managed.identity-provider=no-delete

echo "✓ Keycloak realm avcd applied via keycloak-config-cli"
