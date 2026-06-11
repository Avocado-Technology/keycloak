#!/usr/bin/env bash
# Resolve the local Keycloak Docker container name (avcd-odoo-keycloak-1, odoo-keycloak-1, …).
resolve_kc_container() {
  if [[ -n "${KEYCLOAK_DOCKER_CONTAINER:-}" ]]; then
    if docker ps --format '{{.Names}}' | grep -qx "${KEYCLOAK_DOCKER_CONTAINER}"; then
      printf '%s' "${KEYCLOAK_DOCKER_CONTAINER}"
      return 0
    fi
  fi
  docker ps --format '{{.Names}}' | grep -E 'keycloak-1$' | head -1
}
