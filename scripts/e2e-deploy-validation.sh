#!/usr/bin/env bash
# HTTPS E2E validation after deploy to shared infra IdP (OIDC discovery only).
set -euo pipefail

KEYCLOAK_HOST="${KEYCLOAK_HOST:-auth.avcd.ai}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://${KEYCLOAK_HOST}}"
REALM="${KEYCLOAK_REALM:-avcd}"
EXPECTED_ISS="${KEYCLOAK_URL}/realms/${REALM}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq

echo "Deploy E2E: OIDC discovery at ${KEYCLOAK_URL}"
DISCOVERY="$(curl -sf "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration")"
echo "$DISCOVERY" | jq -e '.issuer and .jwks_uri and .token_endpoint' >/dev/null
ISSUER="$(echo "$DISCOVERY" | jq -r '.issuer')"
if [[ "$ISSUER" != "$EXPECTED_ISS" ]]; then
  echo "Unexpected issuer: got '$ISSUER', expected '$EXPECTED_ISS'" >&2
  exit 1
fi
echo "  issuer: $ISSUER"
echo "  jwks_uri: $(echo "$DISCOVERY" | jq -r '.jwks_uri')"
echo "DEPLOY E2E PASS"
