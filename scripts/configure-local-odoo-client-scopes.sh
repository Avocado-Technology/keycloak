#!/usr/bin/env bash
# Ensure avcd-odoo client accepts openid profile email (Odoo OIDC seed scope).
# Fixes Keycloak invalid_scope when profile client scope was never imported.
set -euo pipefail

KEYCLOAK_DOCKER_CONTAINER="${KEYCLOAK_DOCKER_CONTAINER:-odoo-keycloak-1}"
REALM="${KEYCLOAK_REALM:-avcd}"
CLIENT_ID="${KC_CLIENT_ID:-avcd-odoo}"

if ! docker ps --format '{{.Names}}' | grep -qx "${KEYCLOAK_DOCKER_CONTAINER}"; then
  echo "[odoo-scopes] Container ${KEYCLOAK_DOCKER_CONTAINER} not running; skip" >&2
  exit 0
fi

echo "[odoo-scopes] Syncing default client scopes for ${CLIENT_ID} in realm ${REALM}"

docker exec "${KEYCLOAK_DOCKER_CONTAINER}" bash -c '
set -euo pipefail
/opt/keycloak/bin/kcadm.sh config credentials \
  --server http://127.0.0.1:8080 \
  --realm master \
  --user admin \
  --password "${KEYCLOAK_ADMIN_PASSWORD}"

# Create profile scope if missing (realm import may have been skipped).
PROFILE_COUNT=$(/opt/keycloak/bin/kcadm.sh get client-scopes -r "'"${REALM}"'" -q name=profile --fields name --format csv --noquotes 2>/dev/null | wc -l | tr -d " ")
if [ "${PROFILE_COUNT}" = "0" ]; then
  echo "[odoo-scopes] Creating client scope: profile"
  /opt/keycloak/bin/kcadm.sh create client-scopes -r "'"${REALM}"'" \
    -s name=profile \
    -s protocol=openid-connect
fi

CLIENT_UUID=$(/opt/keycloak/bin/kcadm.sh get clients -r "'"${REALM}"'" -q clientId="'"${CLIENT_ID}"'" --fields id --format csv --noquotes | tail -1)
for SCOPE in openid email profile; do
  SCOPE_ID=$(/opt/keycloak/bin/kcadm.sh get client-scopes -r "'"${REALM}"'" -q name="${SCOPE}" --fields id --format csv --noquotes 2>/dev/null | tail -1)
  if [ -z "${SCOPE_ID}" ]; then
    echo "[odoo-scopes] WARN: missing client scope ${SCOPE}" >&2
    continue
  fi
  if /opt/keycloak/bin/kcadm.sh get "clients/${CLIENT_UUID}/default-client-scopes" -r "'"${REALM}"'" 2>/dev/null | grep -q "\"name\" : \"${SCOPE}\""; then
    continue
  fi
  /opt/keycloak/bin/kcadm.sh update "clients/${CLIENT_UUID}/default-client-scopes/${SCOPE_ID}" -r "'"${REALM}"'" -n
  echo "[odoo-scopes] Attached default scope: ${SCOPE}"
done
'

echo "[odoo-scopes] Done"
