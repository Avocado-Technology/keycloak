#!/usr/bin/env bash
# Fail fast when GitHub Actions secrets are missing (sync-infisical-secrets workflow).
set -euo pipefail

missing=0
for name in SPACES_ACCESS_KEY_ID SPACES_SECRET_ACCESS_KEY PULUMI_CONFIG_PASSPHRASE \
  INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET; do
  if [ -z "${!name:-}" ]; then
    echo "::error::GitHub secret ${name} is not set on Avocado-Technology/keycloak."
    missing=1
  fi
done

if [ "${missing}" -ne 0 ]; then
  echo "Run: bash pulumi/scripts/seed-github-secrets.sh (from pulumi-infra credentials)"
  exit 1
fi
