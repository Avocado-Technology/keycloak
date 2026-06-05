#!/usr/bin/env bash
# Obtain a Bearer token for Infisical API calls (service token or universal auth).
set -euo pipefail

INFISICAL_HOST="${INFISICAL_HOST:-https://secrets.avcd.ai}"

if [[ -n "${INFISICAL_SERVICE_TOKEN:-}" ]]; then
  echo "${INFISICAL_SERVICE_TOKEN}"
  exit 0
fi

if [[ -n "${INFISICAL_CLIENT_ID:-}" && -n "${INFISICAL_CLIENT_SECRET:-}" ]]; then
  curl -sf -X POST "${INFISICAL_HOST}/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"clientId\":\"${INFISICAL_CLIENT_ID}\",\"clientSecret\":\"${INFISICAL_CLIENT_SECRET}\"}" \
    | jq -r '.accessToken // empty' | tr -d '\n\r' || true
  exit 0
fi

echo "infisical-api-token: set INFISICAL_SERVICE_TOKEN or INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET" >&2
exit 1
