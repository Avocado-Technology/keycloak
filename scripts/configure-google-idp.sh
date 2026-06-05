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

require_cmd jq

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

is_local_keycloak() {
  [[ "${KEYCLOAK_URL}" == http://localhost:* || "${KEYCLOAK_URL}" == http://127.0.0.1:* ]]
}

configure_via_docker_kcadm() {
  require_cmd docker
  local container="${KEYCLOAK_DOCKER_CONTAINER:-}"
  if [[ -z "${container}" ]]; then
    container="$(docker ps --format '{{.Names}}' | grep -E 'keycloak-1$' | head -1 || true)"
  fi
  if [[ -z "${container}" ]]; then
    return 1
  fi

  echo "Configuring Google IdP via kcadm in Docker container ${container} (realm ${REALM})"
  local idp_path="/opt/keycloak/data/google-idp.json"
  printf '%s' "${PAYLOAD}" | docker exec -i "${container}" sh -c "cat > '${idp_path}'"

  docker exec "${container}" bash -c '
set -euo pipefail
IDP_FILE="'"${idp_path}"'"
test -f "${IDP_FILE}"
/opt/keycloak/bin/kcadm.sh config credentials \
  --server http://127.0.0.1:8080 \
  --realm master \
  --user "'"${KEYCLOAK_ADMIN}"'" \
  --password "${KEYCLOAK_ADMIN_PASSWORD}"
if /opt/keycloak/bin/kcadm.sh get "identity-provider/instances/google" -r "'"${REALM}"'" >/dev/null 2>&1; then
  /opt/keycloak/bin/kcadm.sh update "identity-provider/instances/google" -r "'"${REALM}"'" -f "${IDP_FILE}"
else
  /opt/keycloak/bin/kcadm.sh create "identity-provider/instances" -r "'"${REALM}"'" -f "${IDP_FILE}"
fi
rm -f "${IDP_FILE}"
'
  echo "Google IdP configured successfully."
}

if is_local_keycloak && configure_via_docker_kcadm; then
  exit 0
fi

require_cmd curl

echo "Configuring Google IdP on ${KEYCLOAK_URL}/admin/realms/${REALM}"

KC_CURL_HEADERS=(-H "Content-Type: application/x-www-form-urlencoded")
if is_local_keycloak; then
  KC_CURL_HEADERS+=(
    -H "X-Forwarded-Proto: http"
    -H "X-Forwarded-Host: localhost"
    -H "X-Forwarded-For: 127.0.0.1"
  )
fi

ADMIN_TOKEN="$(
  curl -sf -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    "${KC_CURL_HEADERS[@]}" \
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

IDP_CURL_HEADERS=(-H "Authorization: Bearer ${ADMIN_TOKEN}" -H "Content-Type: application/json")
if is_local_keycloak; then
  IDP_CURL_HEADERS+=(
    -H "X-Forwarded-Proto: http"
    -H "X-Forwarded-Host: localhost"
    -H "X-Forwarded-For: 127.0.0.1"
  )
fi

HTTP_CODE="$(
  curl -s -o /tmp/keycloak-google-idp-response.json -w "%{http_code}" \
    -X PUT \
    "${IDP_CURL_HEADERS[@]}" \
    -d "$PAYLOAD" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/identity-provider/instances/google"
)"

if [[ "$HTTP_CODE" != "204" && "$HTTP_CODE" != "201" && "$HTTP_CODE" != "200" ]]; then
  echo "Failed to configure Google IdP (HTTP ${HTTP_CODE}):" >&2
  cat /tmp/keycloak-google-idp-response.json >&2 || true
  exit 1
fi

echo "Google IdP configured successfully."
