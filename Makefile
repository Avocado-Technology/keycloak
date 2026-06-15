.PHONY: up down logs validate clean wait test-config test-kamal infisical-check pull-secrets push-secrets push-bootstrap ensure-bootstrap-folder configure-google-idp configure-mcp-dcr apply-config push-client-secrets e2e-deploy e2e-google

COMPOSE ?= docker compose

# Infisical — shared infra project (AVCD Infrastructure)
INFISICAL_API_URL ?= https://secrets.avcd.ai/api
INFISICAL_PROJECT_ID ?= db036f0e-7452-4e17-9573-e5471b45d65f
INFISICAL_SECRET_PATH ?= /keycloak
INFISICAL_BOOTSTRAP_PATH ?= /ci-bootstrap
INFISICAL_ENV ?= prod
INFISICAL_PULL_FILE ?= .env.infisical
INFISICAL_PUSH_FILE ?= .env.keycloak.prod
INFISICAL_CREDENTIALS_FILE ?= .env.deploy
SSH_KEY_FILE ?= $(HOME)/.ssh/id_ed25519
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

# After pulumi keycloak-config apply — allow Claude MCP Dynamic Client Registration
configure-mcp-dcr:
	@chmod +x scripts/configure-mcp-dcr-policies.sh
	KEYCLOAK_URL=$${KEYCLOAK_URL:-https://auth.avcd.ai} bash scripts/configure-mcp-dcr-policies.sh

# Deployed realm avcd — keycloak-config-cli (replaces pulumi keycloak-config stack)
apply-config:
	@chmod +x scripts/apply-keycloak-config.sh scripts/prepare-keycloak-config-env.sh
	KEYCLOAK_URL=$${KEYCLOAK_URL:-http://localhost:8080} bash scripts/apply-keycloak-config.sh

push-client-secrets:
	@chmod +x scripts/push-client-secrets-to-infisical.sh scripts/prepare-keycloak-config-env.sh
	bash scripts/push-client-secrets-to-infisical.sh

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
	./tests/test_push_secrets.sh

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

# Upload app secrets from dotenv to Infisical (e.g. make push-secrets INFISICAL_ENV=prod).
push-secrets: infisical-check
	@test -f "$(INFISICAL_PUSH_FILE)" || (echo "❌ Missing $(INFISICAL_PUSH_FILE)" && exit 1)
	@set -a; [ -f "$(INFISICAL_CREDENTIALS_FILE)" ] && . "$(INFISICAL_CREDENTIALS_FILE)"; set +a; \
	CID="$${KEYCLOAK_INFISICAL_CLIENT_ID:-$$INFISICAL_CLIENT_ID}"; \
	CSEC="$${KEYCLOAK_INFISICAL_CLIENT_SECRET:-$$INFISICAL_CLIENT_SECRET}"; \
	PID="$${KEYCLOAK_INFISICAL_PROJECT_ID:-$(INFISICAL_PROJECT_ID)}"; \
	DOMAIN="$${INFISICAL_API_URL%/api}"; \
	INFISICAL_TOKEN=$$(infisical login --method=universal-auth \
	  --client-id="$$CID" --client-secret="$$CSEC" \
	  --domain="$$DOMAIN" --silent --plain); \
	count=0; \
	while IFS= read -r line || [ -n "$$line" ]; do \
	  case "$$line" in ''|\#*) continue ;; esac; \
	  key=$${line%%=*}; val=$${line#*=}; \
	  [ -n "$$key" ] || continue; \
	  infisical secrets set "$$key=$$val" \
	    --projectId="$$PID" --env="$(INFISICAL_ENV)" --path="$(INFISICAL_SECRET_PATH)" \
	    --domain="$$DOMAIN" --token="$$INFISICAL_TOKEN" --silent; \
	  count=$$((count + 1)); \
	done < "$(INFISICAL_PUSH_FILE)"; \
	echo "✓ Pushed $$count secret(s) to $(INFISICAL_SECRET_PATH) ($(INFISICAL_ENV))"

# Ensure /ci-bootstrap folder exists (Infisical CLI cannot create folders).
ensure-bootstrap-folder: infisical-check
	@set -a; [ -f "$(INFISICAL_CREDENTIALS_FILE)" ] && . "$(INFISICAL_CREDENTIALS_FILE)"; set +a; \
	CID="$${KEYCLOAK_INFISICAL_CLIENT_ID:-$$INFISICAL_CLIENT_ID}"; \
	CSEC="$${KEYCLOAK_INFISICAL_CLIENT_SECRET:-$$INFISICAL_CLIENT_SECRET}"; \
	PID="$${KEYCLOAK_INFISICAL_PROJECT_ID:-$(INFISICAL_PROJECT_ID)}"; \
	API="$(INFISICAL_API_URL)"; \
	TOKEN=$$(curl -sS "$$API/v1/auth/universal-auth/login" -H 'Content-Type: application/json' \
	  -d "{\"clientId\":\"$$CID\",\"clientSecret\":\"$$CSEC\"}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))'); \
	[ -n "$$TOKEN" ] || (echo "❌ Infisical universal-auth login failed" && exit 1); \
	STATUS=$$(curl -sS -o /tmp/infisical-folder.json -w '%{http_code}' \
	  -H "Authorization: Bearer $$TOKEN" \
	  "$$API/v1/folders?workspaceId=$$PID&environment=$(INFISICAL_ENV)&path=%2F"); \
	if [ "$$STATUS" = "200" ] && python3 -c 'import json;d=json.load(open("/tmp/infisical-folder.json"));exit(0 if any(f["name"]=="ci-bootstrap" for f in d.get("folders",[])) else 1)' 2>/dev/null; then \
	  echo "✓ $(INFISICAL_BOOTSTRAP_PATH) folder exists"; \
	else \
	  curl -sS -X POST "$$API/v1/folders" -H "Authorization: Bearer $$TOKEN" -H 'Content-Type: application/json' \
	    -d "{\"workspaceId\":\"$$PID\",\"environment\":\"$(INFISICAL_ENV)\",\"name\":\"ci-bootstrap\"}" >/dev/null \
	    || (echo "❌ Failed to create $(INFISICAL_BOOTSTRAP_PATH) folder" && exit 1); \
	  echo "✓ Created $(INFISICAL_BOOTSTRAP_PATH) folder"; \
	fi

# Upload deploy SSH private key to Infisical /ci-bootstrap.
push-bootstrap: infisical-check ensure-bootstrap-folder
	@test -f "$(SSH_KEY_FILE)" || (echo "❌ Missing SSH key: $(SSH_KEY_FILE)" && exit 1)
	@set -a; [ -f "$(INFISICAL_CREDENTIALS_FILE)" ] && . "$(INFISICAL_CREDENTIALS_FILE)"; set +a; \
	CID="$${KEYCLOAK_INFISICAL_CLIENT_ID:-$$INFISICAL_CLIENT_ID}"; \
	CSEC="$${KEYCLOAK_INFISICAL_CLIENT_SECRET:-$$INFISICAL_CLIENT_SECRET}"; \
	PID="$${KEYCLOAK_INFISICAL_PROJECT_ID:-$(INFISICAL_PROJECT_ID)}"; \
	DOMAIN="$${INFISICAL_API_URL%/api}"; \
	INFISICAL_TOKEN=$$(infisical login --method=universal-auth \
	  --client-id="$$CID" --client-secret="$$CSEC" \
	  --domain="$$DOMAIN" --silent --plain) || exit 1; \
	infisical secrets set "DO_DEPLOY_SSH_KEY=$$(cat '$(SSH_KEY_FILE)')" \
	  --projectId="$$PID" --env="$(INFISICAL_ENV)" --path="$(INFISICAL_BOOTSTRAP_PATH)" \
	  --domain="$$DOMAIN" --token="$$INFISICAL_TOKEN" --silent >/dev/null \
	  || (echo "❌ infisical secrets set DO_DEPLOY_SSH_KEY failed" && exit 1); \
	echo "✓ Pushed DO_DEPLOY_SSH_KEY → $(INFISICAL_BOOTSTRAP_PATH) ($(INFISICAL_ENV))"

e2e-deploy:
	@chmod +x scripts/e2e-deploy-validation.sh
	./scripts/e2e-deploy-validation.sh
