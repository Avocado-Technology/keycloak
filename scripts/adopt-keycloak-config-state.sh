#!/usr/bin/env bash
# Brownfield: adopt existing Keycloak realm/clients into keycloak-config stack state.
#
# 1. If pulumi-infra/keycloak-config state exists, import it (project rename avcd-infra → avcd-keycloak).
# 2. Else import the avcd realm only (realm already exists on auth.avcd.ai).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULUMI_DIR="${ROOT}/pulumi"
cd "${PULUMI_DIR}"

STACK="${PULUMI_STACK:-keycloak-config}"
OLD_STACK="organization/avcd-infra/keycloak-config"

: "${PULUMI_CONFIG_PASSPHRASE:?PULUMI_CONFIG_PASSPHRASE required}"

pulumi stack select "${STACK}" --create 2>/dev/null || pulumi stack select "${STACK}"

if pulumi stack --show-urns --stack "${STACK}" 2>/dev/null | grep -q 'keycloak:index/realm:Realm'; then
  echo "✓ keycloak-config stack already tracks Keycloak realm; skip adopt"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

if pulumi stack export --stack "${OLD_STACK}" > "${TMP}" 2>/dev/null; then
  echo "Adopting state from ${OLD_STACK} → avcd-keycloak/${STACK}"
  sed 's/::avcd-infra::/::avcd-keycloak::/g' "${TMP}" > "${TMP}.migrated"
  pulumi stack import --stack "${STACK}" < "${TMP}.migrated"
  echo "✓ Migrated Keycloak config state from pulumi-infra"
  exit 0
fi

echo "No ${OLD_STACK} state; importing existing realm avcd into stack ${STACK}"
pulumi import keycloak:index/realm:Realm avcd-realm avcd --yes --stack "${STACK}"
echo "✓ Imported realm avcd"
