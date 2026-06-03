# Keycloak Dockerfile — Minimal wrapper around upstream Keycloak image
# Pinned to quay.io/keycloak/keycloak:26.0 for stability
# Kamal manages the build/push to DOCR for deployment

FROM quay.io/keycloak/keycloak:26.0

# Kamal identifies containers by this label (required for deploy/prune).
LABEL service="avcd-keycloak"

# Default command starts Keycloak in production mode
# Environment variables (KC_DB_URL, KC_DB_USERNAME, etc.) are injected by Kamal
CMD ["start"]
