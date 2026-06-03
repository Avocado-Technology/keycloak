#!/usr/bin/env bash
# Point Pulumi state at the same DO Spaces bucket as pulumi-infra.
set -euo pipefail

: "${SPACES_ACCESS_KEY_ID:?SPACES_ACCESS_KEY_ID required}"
: "${SPACES_SECRET_ACCESS_KEY:?SPACES_SECRET_ACCESS_KEY required}"

BUCKET="${PULUMI_STATE_BUCKET:-avcd-infra-tfstate}"
REGION="${PULUMI_STATE_REGION:-us-east-1}"
ENDPOINT="${PULUMI_STATE_ENDPOINT:-sfo3.digitaloceanspaces.com}"
ORG="${PULUMI_ORG:-organization}"

export AWS_ACCESS_KEY_ID="${SPACES_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${SPACES_SECRET_ACCESS_KEY}"
export AWS_EC2_METADATA_DISABLED=true

BACKEND_URL="s3://${BUCKET}/pulumi?region=${REGION}&endpoint=${ENDPOINT}"

pulumi login "${BACKEND_URL}"
pulumi org set-default "${ORG}" 2>/dev/null || true

echo "✓ Pulumi backend: ${BACKEND_URL}"
echo "✓ Organization: ${ORG} (stacks: organization/avcd-keycloak/secrets)"
