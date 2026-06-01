.PHONY: up down logs validate clean wait test-config test-kamal infisical-check pull-secrets configure-google-idp e2e-deploy e2e-google

COMPOSE ?= docker compose

# Infisical — shared infra project (avcd-infra), folder /keycloak
INFISICAL_API_URL ?= https://secrets.dev.avcd.ai/api
INFISICAL_PROJECT_ID ?= 802aad98-56e1-4b3e-a0a9-68b3bfec4537
INFISICAL_SECRET_PATH ?= /keycloak
INFISICAL_ENV ?= dev
INFISICAL_PULL_FILE ?= .env.infisical
INFISICAL_CREDENTIALS_FILE ?= .env.deploy
INFISICAL_REQUIRED_SECRETS := KC_DB_URL KC_DB_USERNAME KC_DB_PASSWORD KEYCLOAK_ADMIN KEYCLOAK_ADMIN_PASSWORD KEYCLOAK_HOST KEYCLOAK_POSTGRES_BOOTSTRAP_URI

up:
	$(COMPOSE) up -d --wait

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f keycloak

wait:
	./scripts/wait-for-keycloak.sh

validate: up wait
	./scripts/e2e-local-validation.sh

configure-google-idp:
	@chmod +x scripts/configure-google-idp.sh
	./scripts/configure-google-idp.sh

e2e-google: configure-google-idp
	@chmod +x scripts/e2e-google-idp-validation.sh
	./scripts/e2e-google-idp-validation.sh

clean:
	$(COMPOSE) down -v

test-config:
	@chmod +x tests/*.sh scripts/*.sh
	./tests/test_compose_config.sh
	./tests/test_realm_google_idp.sh
	./tests/test_configure_google_idp.sh

test-kamal:
	@chmod +x tests/*.sh
	./tests/test_kamal_config.sh
	./tests/test_kamal_workflow.sh

infisical-check:
	@command -v infisical >/dev/null 2>&1 || (echo "❌ Infisical CLI not installed. Run: brew install infisical/get-cli/infisical" && exit 1)
	@test -f "$(INFISICAL_CREDENTIALS_FILE)" || test -n "$$KEYCLOAK_INFISICAL_CLIENT_ID" || (echo "❌ Missing KEYCLOAK_INFISICAL_* or $(INFISICAL_CREDENTIALS_FILE)" && exit 1)
	@echo "✓ Infisical CLI ready"

pull-secrets: infisical-check
	@set -a; [ -f "$(INFISICAL_CREDENTIALS_FILE)" ] && . "$(INFISICAL_CREDENTIALS_FILE)"; set +a; \
	CID="$${KEYCLOAK_INFISICAL_CLIENT_ID:-$$INFISICAL_CLIENT_ID}"; \
	CSEC="$${KEYCLOAK_INFISICAL_CLIENT_SECRET:-$$INFISICAL_CLIENT_SECRET}"; \
	PID="$${KEYCLOAK_INFISICAL_PROJECT_ID:-$(INFISICAL_PROJECT_ID)}"; \
	export INFISICAL_API_URL="$(INFISICAL_API_URL)"; \
	INFISICAL_TOKEN=$$(infisical login --method=universal-auth \
	  --client-id="$$CID" --client-secret="$$CSEC" \
	  --domain="$${INFISICAL_API_URL%/api}" --silent --plain); \
	infisical export --env="$(INFISICAL_ENV)" --path="$(INFISICAL_SECRET_PATH)" \
	  --projectId="$$PID" --token="$$INFISICAL_TOKEN" \
	  --format=dotenv --domain="$${INFISICAL_API_URL%/api}" --silent \
	  > "$(INFISICAL_PULL_FILE)"; \
	test -s "$(INFISICAL_PULL_FILE)" || (echo "❌ Infisical export empty" && exit 1); \
	echo "✓ Exported secrets → $(INFISICAL_PULL_FILE)"

e2e-deploy:
	@chmod +x scripts/e2e-deploy-validation.sh
	./scripts/e2e-deploy-validation.sh
