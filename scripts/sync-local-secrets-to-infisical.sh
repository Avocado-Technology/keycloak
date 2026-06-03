#!/usr/bin/env bash
# On-demand sync: optional GOOGLE_* into Infisical /keycloak prod.
# Core catalog (KC_*, admin, deploy host) is owned by pulumi stack: sync-infisical-secrets workflow.
#
# Usage (from keycloak/):
#   bash scripts/sync-local-secrets-to-infisical.sh
#
# Env:
#   INFISICAL_TOKEN or INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET
#   GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET (optional)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for f in "${ROOT}/../pulumi-infra/.env" "${ROOT}/.env.deploy"; do
  if [ -f "${f}" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${f}"
    set +a
  fi
done

INFISICAL_HOST="${INFISICAL_HOST:-https://secrets.avcd.ai}"
INFISICAL_PROJECT_ID="${INFISICAL_INFRA_PROJECT_ID:-db036f0e-7452-4e17-9573-e5471b45d65f}"
ENV_SLUG="${INFISICAL_ENV:-prod}"
SECRET_PATH="/keycloak"

if [[ -z "${INFISICAL_TOKEN:-}" ]]; then
  INFISICAL_TOKEN="$("${ROOT}/tests/e2e/helpers/get-infisical-token.sh")"
fi
export INFISICAL_TOKEN

upsert_secret() {
  local key="$1"
  local value="$2"
  local body
  body="$(SECRET_VALUE="$value" python3 -c "
import json, os
print(json.dumps({
  'workspaceId': os.environ['INFISICAL_PROJECT_ID'],
  'environment': os.environ['INFISICAL_ENV_SLUG'],
  'secretPath': os.environ['INFISICAL_SECRET_PATH'],
  'secretValue': os.environ['SECRET_VALUE'],
  'type': 'shared',
}))
")"
  export INFISICAL_PROJECT_ID INFISICAL_ENV_SLUG="${ENV_SLUG}" INFISICAL_SECRET_PATH="${SECRET_PATH}"
  curl -sf -X POST \
    -H "Authorization: Bearer ${INFISICAL_TOKEN}" \
    -H "Content-Type: application/json" \
    "${INFISICAL_HOST}/api/v3/secrets/raw/${key}" \
    -d "${body}" >/dev/null
  echo "✓ ${key}"
}

if [[ -n "${GOOGLE_CLIENT_ID:-}" ]]; then
  upsert_secret GOOGLE_CLIENT_ID "$GOOGLE_CLIENT_ID"
fi
if [[ -n "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  upsert_secret GOOGLE_CLIENT_SECRET "$GOOGLE_CLIENT_SECRET"
fi

if [[ -z "${GOOGLE_CLIENT_ID:-}" && -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
  echo "No GOOGLE_* env set; nothing to sync. Run pulumi sync for core /keycloak secrets."
  exit 0
fi

echo "✓ Optional Keycloak secrets synced to Infisical"
