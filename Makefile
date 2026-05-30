.PHONY: up down logs validate clean wait test-config

COMPOSE ?= docker compose

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
