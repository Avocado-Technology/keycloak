#!/usr/bin/env bash
# Local dev: allow HTTP logins (sslRequired=none). Fixes LOGIN_ERROR ssl_required when
# the browser is not seen as localhost (e.g. remote preview / tunnel).
set -euo pipefail

KEYCLOAK_DOCKER_CONTAINER="${KEYCLOAK_DOCKER_CONTAINER:-odoo-keycloak-1}"
REALM="${KEYCLOAK_REALM:-avcd}"

if ! docker ps --format '{{.Names}}' | grep -qx "${KEYCLOAK_DOCKER_CONTAINER}"; then
  echo "[realm-http] Keycloak container ${KEYCLOAK_DOCKER_CONTAINER} not running; skip" >&2
  exit 0
fi

echo "[realm-http] Setting realm ${REALM} sslRequired=none (local HTTP only)"
docker exec "${KEYCLOAK_DOCKER_CONTAINER}" bash -c "
set -euo pipefail
/opt/keycloak/bin/kcadm.sh config credentials \
  --server http://127.0.0.1:8080 \
  --realm master \
  --user admin \
  --password \"\${KEYCLOAK_ADMIN_PASSWORD}\"
/opt/keycloak/bin/kcadm.sh update realms/${REALM} -s sslRequired=none
"
echo "[realm-http] Done"
