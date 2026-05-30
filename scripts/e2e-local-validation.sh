#!/usr/bin/env bash
# E2E validation: OIDC discovery, token issuance, JWKS JWT verification.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
REALM="${KEYCLOAK_REALM:-avcd}"
CLIENT_ID="${KEYCLOAK_TEST_CLIENT_ID:-avcd-validation}"
CLIENT_SECRET="${KEYCLOAK_TEST_CLIENT_SECRET:?set KEYCLOAK_TEST_CLIENT_SECRET in .env}"
TEST_USER="${KEYCLOAK_TEST_USER:-dev@avcd.local}"
TEST_PASS="${KEYCLOAK_TEST_PASSWORD:?set KEYCLOAK_TEST_PASSWORD in .env}"
EXPECTED_AUD="${KEYCLOAK_API_AUDIENCE:-https://dev.avcd.ai/api}"
EXPECTED_ISS="${KEYCLOAK_URL}/realms/${REALM}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq
require_cmd python3

PYTHON_BIN="${ROOT}/.venv/bin/python"

ensure_pyjwt() {
  if [[ ! -x "${PYTHON_BIN}" ]]; then
    echo "Creating Python venv for JWT verification..."
    python3 -m venv "${ROOT}/.venv"
    "${ROOT}/.venv/bin/pip" install --quiet --disable-pip-version-check pyjwt cryptography
  fi
  "${PYTHON_BIN}" - <<'PY' 2>/dev/null && return 0
import jwt  # noqa: F401
PY
  "${ROOT}/.venv/bin/pip" install --quiet --disable-pip-version-check pyjwt cryptography
}

echo "Step 1/3: OIDC discovery"
DISCOVERY="$(curl -sf "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration")"
echo "$DISCOVERY" | jq -e '.issuer and .jwks_uri and .token_endpoint' >/dev/null
ISSUER="$(echo "$DISCOVERY" | jq -r '.issuer')"
if [[ "$ISSUER" != "$EXPECTED_ISS" ]]; then
  echo "Unexpected issuer: got '$ISSUER', expected '$EXPECTED_ISS'" >&2
  exit 1
fi
echo "  issuer: $ISSUER"

echo "Step 2/3: Password grant token"
TOKEN_RESP="$(curl -sf -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${TEST_USER}" \
  -d "password=${TEST_PASS}" \
  -d "scope=openid avcd-api-audience")"
ACCESS_TOKEN="$(echo "$TOKEN_RESP" | jq -r '.access_token')"
if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo "Token response did not include access_token:" >&2
  echo "$TOKEN_RESP" >&2
  exit 1
fi
echo "  access_token length: ${#ACCESS_TOKEN}"

echo "Step 3/3: JWKS JWT verification"
ensure_pyjwt
export ACCESS_TOKEN EXPECTED_AUD EXPECTED_ISS KEYCLOAK_URL REALM
"${PYTHON_BIN}" - <<'PY'
import os
import sys

import jwt
from jwt import PyJWKClient

token = os.environ["ACCESS_TOKEN"]
expected_aud = os.environ["EXPECTED_AUD"]
expected_iss = os.environ["EXPECTED_ISS"]
realm = os.environ["REALM"]
base = os.environ["KEYCLOAK_URL"].rstrip("/")
jwks_uri = f"{base}/realms/{realm}/protocol/openid-connect/certs"

client = PyJWKClient(jwks_uri)
key = client.get_signing_key_from_jwt(token)
payload = jwt.decode(
    token,
    key.key,
    algorithms=["RS256"],
    audience=expected_aud,
    issuer=expected_iss,
)

sub = payload.get("sub")
if not sub:
    print("JWT missing sub claim", file=sys.stderr)
    sys.exit(1)

print(f"E2E PASS: sub={sub} aud={payload.get('aud')}")
PY

echo "All E2E checks passed."
