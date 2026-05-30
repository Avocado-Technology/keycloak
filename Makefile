.PHONY: up down logs validate clean wait test-config test-production test-deploy-workflow infisical-check pull-secrets e2e-deploy

COMPOSE ?= docker compose

# Infisical — keycloak project (see infra/modules/keycloak)
INFISICAL_API_URL ?= https://secrets.dev.avcd.ai/api
INFISICAL_PROJECT_ID ?= 885103af-2564-4fbf-995b-9ba144c6cc3b
INFISICAL_SECRET_PATH ?= /
INFISICAL_ENV ?= dev
INFISICAL_PULL_FILE ?= .env.infisical
INFISICAL_CREDENTIALS_FILE ?= .env.deploy
INFISICAL_REQUIRED_SECRETS := KC_DB_URL KC_DB_USERNAME KC_DB_PASSWORD KEYCLOAK_ADMIN KEYCLOAK_ADMIN_PASSWORD KEYCLOAK_HOST

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

clean:
	$(COMPOSE) down -v

test-config:
	./tests/test_compose_config.sh

test-production:
	./tests/test_production_compose.sh

test-deploy-workflow:
	./tests/test_deploy_workflow.sh

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
