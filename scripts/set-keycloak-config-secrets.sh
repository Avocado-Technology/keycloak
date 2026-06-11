#!/usr/bin/env bash
# Set Pulumi keycloak-config stack secrets from Infisical /keycloak (admin password).
#
# Prerequisites:
#   - infisical CLI logged in, or INFISICAL_TOKEN / universal auth env vars
#   - pulumi logged into Spaces backend
#
# Usage:
#   source scripts/load-env.sh && bash scripts/pulumi-login-spaces.sh
#   bash scripts/set-keycloak-config-secrets.sh
#   pulumi preview --stack keycloak-config
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULUMI_DIR="${ROOT}/pulumi"
cd "${PULUMI_DIR}"

STACK="${PULUMI_STACK:-keycloak-config}"
INFISICAL_API_URL="${INFISICAL_API_URL:-https://secrets.avcd.ai/api}"
INFISICAL_HOST="${INFISICAL_HOST:-${INFISICAL_API_URL%/api}}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_SECRET_PATH="${INFISICAL_SECRET_PATH:-/keycloak}"

if [ -f "${ROOT}/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

: "${PULUMI_CONFIG_PASSPHRASE:?PULUMI_CONFIG_PASSPHRASE required}"

pulumi stack select "${STACK}" --create 2>/dev/null || pulumi stack select "${STACK}"

if [ -z "${INFISICAL_TOKEN:-}" ]; then
  if [ -n "${INFISICAL_CLIENT_ID:-}" ] && [ -n "${INFISICAL_CLIENT_SECRET:-}" ]; then
    export INFISICAL_TOKEN="$(
      infisical login --method=universal-auth \
        --client-id="${INFISICAL_CLIENT_ID}" \
        --client-secret="${INFISICAL_CLIENT_SECRET}" \
        --domain="${INFISICAL_HOST}" --silent --plain
    )"
  else
    echo "ERROR: Set INFISICAL_TOKEN or INFISICAL_CLIENT_ID + INFISICAL_CLIENT_SECRET" >&2
    exit 1
  fi
fi

: "${INFISICAL_INFRA_PROJECT_ID:?INFISICAL_INFRA_PROJECT_ID required (avcd-infra project id)}"

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

infisical export --env="${INFISICAL_ENV}" --path="${INFISICAL_SECRET_PATH}" \
  --projectId="${INFISICAL_INFRA_PROJECT_ID}" --token="${INFISICAL_TOKEN}" \
  --format=dotenv --domain="${INFISICAL_HOST}" --silent > "${TMP}"

# shellcheck disable=SC1090
source "${TMP}"

ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-}"
if [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERROR: KEYCLOAK_ADMIN_PASSWORD not found in Infisical ${INFISICAL_SECRET_PATH}" >&2
  exit 1
fi

pulumi config set --secret keycloakAdminPassword "${ADMIN_PASSWORD}" --stack "${STACK}"

if [ -n "${GOOGLE_CLIENT_ID:-}" ] && [ -n "${GOOGLE_CLIENT_SECRET:-}" ]; then
  pulumi config set --secret googleClientId "${GOOGLE_CLIENT_ID}" --stack "${STACK}"
  pulumi config set --secret googleClientSecret "${GOOGLE_CLIENT_SECRET}" --stack "${STACK}"
  echo "✓ googleClientId / googleClientSecret set from Infisical (if present)"
fi

echo "✓ keycloakAdminPassword set on stack ${STACK}"
