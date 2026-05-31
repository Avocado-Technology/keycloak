---
name: keycloak-local
description: Local Docker setup and validation for self-hosted Keycloak IdP in the AVCD keycloak repo
---

# Keycloak Local Development

> **Related**: [keycloak-authorization](./keycloak-authorization/SKILL.md) | [terraform-keycloak](../../../infra/.cursor/skills/terraform-keycloak/SKILL.md) | [Auth0 Terraform Setup](~/.cursor/skills/terraform-auth0-setup/SKILL.md)

## Overview

The `keycloak` repo runs a production-like Keycloak 26 stack (PostgreSQL + realm import) for validating OIDC before replacing or complementing Auth0.

## Quick Start

```bash
cd keycloak
cp .env.example .env
make up
make validate
```

## Key URLs

| URL | Purpose |
|-----|---------|
| `http://localhost:8080/admin` | Admin console |
| `http://localhost:8080/realms/avcd/.well-known/openid-configuration` | OIDC discovery |
| `http://localhost:8080/realms/avcd/protocol/openid-connect/certs` | JWKS |

## Realm Clients

| Client | Type | Use |
|--------|------|-----|
| `avcd-web` | Confidential | Next.js auth code flow |
| `avcd-mcp` | Public + PKCE | MCP OAuth 2.1 |
| `avcd-validation` | Confidential + password grant | Local/CI only |

## Token Contract (matches API)

- **Algorithm**: RS256
- **Issuer**: `http://localhost:8080/realms/avcd`
- **API audience**: `https://dev.avcd.ai/api`
- **MCP audience**: `https://dev.avcd.ai/mcp`

## Patterns

### Validate stack after changes

```bash
make clean && make up && make validate
```

### Export realm from Admin UI changes

```bash
./scripts/export-realm.sh
git diff config/avcd-realm.json
```

### Integrate with AVCD API (future)

Mirror `verify_auth0_token` in `api/src/auth.py`:

```python
jwks_uri = f"{settings.keycloak_url}/realms/avcd/protocol/openid-connect/certs"
issuer = f"{settings.keycloak_url}/realms/avcd"
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Port 8080 in use | `lsof -i :8080` or change compose port mapping |
| Realm not imported | `make clean && make up`; check `docker compose logs keycloak` |
| JWT audience mismatch | Ensure client scope `avcd-api-audience` is default |
| Slow startup | Wait up to 90s; Keycloak healthcheck has long `start_period` |
| `permission denied for schema public` on DO Postgres | Run one-time grant as `doadmin` on DB `keycloak` (see Dev Deployment below) |

## References

- [Keycloak Docker guide](https://www.keycloak.org/server/containers)
- [Realm import](https://www.keycloak.org/server/importExport)

## Dev Deployment (DigitalOcean)

Production deploy uses `deploy/production/docker-compose.yml` on the dev droplet behind Traefik at `auth.dev.avcd.ai`.

### Prerequisites (infra Phase 1)

- Terraform `enable_keycloak_dev=true` applied (Postgres DB/user, Infisical secrets in infra project, DNS)
- Infisical **infra project** (`avcd-infra`): `802aad98-56e1-4b3e-a0a9-68b3bfec4537`, secrets folder **`/keycloak`**
- Machine Identity with Universal Auth and read access to `/keycloak` in the infra project (reuse infra Terraform MI or create in UI)
- **One-time Postgres grant** (DO Managed PG 15+): from the dev droplet as `doadmin`:

```bash
psql "postgresql://doadmin@<postgres-host>:25060/keycloak?sslmode=require" -v ON_ERROR_STOP=1 <<'SQL'
GRANT ALL ON SCHEMA public TO keycloak;
ALTER SCHEMA public OWNER TO keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
SQL
```

### GitHub Environment `development` (keycloak repo)

Bootstrap only — app and deploy config live in Infisical `/keycloak` (see `infra/.cursor/skills/secrets-architecture/SKILL.md`):

```bash
cd ../infra
./scripts/sync-github-bootstrap.sh keycloak
```

Requires `gh auth login` with **repo + admin:repo** (secrets write). Reads Infisical MI from `infra/.env`.

| Secret | Purpose |
|--------|---------|
| `KEYCLOAK_INFISICAL_CLIENT_ID` | MI Universal Auth client ID |
| `KEYCLOAK_INFISICAL_CLIENT_SECRET` | MI Universal Auth client secret |
| `DO_DEPLOY_SSH_KEY` | SSH private key for droplet deploy |

Infisical export (Terraform-managed) includes: `DO_DEPLOY_*`, `KEYCLOAK_POSTGRES_BOOTSTRAP_URI`, `KC_*`, admin password, `KEYCLOAK_HOST`.

### Verify Infisical export locally

```bash
export KEYCLOAK_INFISICAL_CLIENT_ID=...
export KEYCLOAK_INFISICAL_CLIENT_SECRET=...
make pull-secrets
grep KC_DB_URL .env.infisical
```

### Deploy

Push to `main` (paths under `deploy/` or `config/`) or run `Deploy Keycloak to DigitalOcean (dev)` workflow.

Post-deploy E2E:

```bash
KEYCLOAK_HOST=auth.dev.avcd.ai make e2e-deploy
```

Expected: `DEPLOY E2E PASS` and issuer `https://auth.dev.avcd.ai/realms/avcd`.
