#!/usr/bin/env bash
# Push Pulumi + Infisical write credentials to Avocado-Technology/keycloak (sync workflow).
#
# Usage (from keycloak/pulumi/):
#   bash scripts/seed-github-secrets.sh
#
# Reads SPACES_* and PULUMI_CONFIG_PASSPHRASE from pulumi-infra/.env when present.
# Reads INFISICAL_CLIENT_* from pulumi-infra/.env or infiscal/.env.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${GITHUB_REPO:-Avocado-Technology/keycloak}"
PULUMI_INFRA_ENV="${PULUMI_INFRA_ENV:-${ROOT}/../../pulumi-infra/.env}"
INFISICAL_ENV_FILE="${INFISICAL_ENV_FILE:-${ROOT}/../../infisical/.env}"

for f in "${PULUMI_INFRA_ENV}" "${INFISICAL_ENV_FILE}"; do
  if [ -f "${f}" ]; then
    set -a
    # shellcheck disable=SC1091
    source "${f}"
    set +a
  fi
done

export GH_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN required}"
: "${SPACES_ACCESS_KEY_ID:?SPACES_ACCESS_KEY_ID required}"
: "${SPACES_SECRET_ACCESS_KEY:?SPACES_SECRET_ACCESS_KEY required}"
: "${PULUMI_CONFIG_PASSPHRASE:?PULUMI_CONFIG_PASSPHRASE required}"
: "${INFISICAL_CLIENT_ID:?INFISICAL_CLIENT_ID required}"
: "${INFISICAL_CLIENT_SECRET:?INFISICAL_CLIENT_SECRET required}"

gh secret set SPACES_ACCESS_KEY_ID --body "${SPACES_ACCESS_KEY_ID}" --repo "${REPO}"
gh secret set SPACES_SECRET_ACCESS_KEY --body "${SPACES_SECRET_ACCESS_KEY}" --repo "${REPO}"
gh secret set PULUMI_CONFIG_PASSPHRASE --body "${PULUMI_CONFIG_PASSPHRASE}" --repo "${REPO}"
gh secret set INFISICAL_CLIENT_ID --body "${INFISICAL_CLIENT_ID}" --repo "${REPO}"
gh secret set INFISICAL_CLIENT_SECRET --body "${INFISICAL_CLIENT_SECRET}" --repo "${REPO}"

echo "✓ Pulumi sync secrets set on ${REPO}"
