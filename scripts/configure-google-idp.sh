#!/usr/bin/env bash
# DEPRECATED: Google IdP is managed by infra/keycloak-config Terraform
# (keycloak_oidc_google_identity_provider). CI runs keycloak-config-apply after deploy.
# Kept for local break-glass only — prefer: cd infra/keycloak-config && terraform apply
#
# Idempotently configure Google identity provider credentials via Keycloak Admin API.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="${KEYCLOAK_REALM:-avcd}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:?set KEYCLOAK_ADMIN_PASSWORD}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:?set GOOGLE_CLIENT_ID}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:?set GOOGLE_CLIENT_SECRET}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq

echo "Configuring Google IdP on ${KEYCLOAK_URL}/admin/realms/${REALM}"

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

PAYLOAD="$(jq -n \
  --arg clientId "$GOOGLE_CLIENT_ID" \
  --arg clientSecret "$GOOGLE_CLIENT_SECRET" \
  '{
    alias: "google",
    displayName: "Google",
    providerId: "google",
    enabled: true,
    trustEmail: true,
    storeToken: false,
    linkOnly: false,
    firstBrokerLoginFlowAlias: "first broker login",
    config: {
      clientId: $clientId,
      clientSecret: $clientSecret,
      defaultScope: "openid email profile",
      syncMode: "IMPORT"
    }
  }')"

HTTP_CODE="$(
  curl -s -o /tmp/keycloak-google-idp-response.json -w "%{http_code}" \
    -X PUT \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/identity-provider/instances/google"
)"

if [[ "$HTTP_CODE" != "204" && "$HTTP_CODE" != "201" && "$HTTP_CODE" != "200" ]]; then
  echo "Failed to configure Google IdP (HTTP ${HTTP_CODE}):" >&2
  cat /tmp/keycloak-google-idp-response.json >&2 || true
  exit 1
fi

echo "Google IdP configured successfully."
