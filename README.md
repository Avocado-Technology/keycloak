# AVCD Keycloak

Self-hosted [Keycloak](https://www.keycloak.org/) identity provider for the AVCD platform. Local-first Docker stack to validate OIDC/OAuth2 before integrating with web, API, and MCP services.

## Quick start

```bash
cp .env.example .env
make up          # start PostgreSQL + Keycloak
make validate    # OIDC discovery + token + JWKS verification
```

Admin console: http://localhost:8080/admin (credentials from `.env`)

AVCD realm OIDC discovery: http://localhost:8080/realms/avcd/.well-known/openid-configuration

## What this repo provides

| Resource | Local value |
|----------|-------------|
| Realm | `avcd` |
| API audience | `https://dev.avcd.ai/api` |
| MCP audience | `https://dev.avcd.ai/mcp` |
| Web client | `avcd-web` (confidential) |
| MCP client | `avcd-mcp` (public + PKCE) |
| Validation client | `avcd-validation` (CI/local only) |
| Test user | `dev@avcd.local` |

## Commands

| Command | Description |
|---------|-------------|
| `make up` | Start stack and wait for health |
| `make down` | Stop containers (keep data) |
| `make clean` | Stop and remove volumes |
| `make validate` | Run full E2E validation |
| `make test-config` | Static repo/compose checks |
| `make logs` | Follow Keycloak logs |

## Realm configuration

| Environment | Source of truth | Mechanism |
|-------------|-----------------|-----------|
| **Local** | `config/avcd-realm.json` | `--import-realm` on first boot (`docker-compose.yml`) |
| **Deployed prod** | `avcd-infra/modules/keycloak-config` | Terraform (realm apply is out of scope for Kamal deploy) |

Local realm settings are imported from `config/avcd-realm.json` on first boot (`--import-realm`).

Production Keycloak runs at **`https://auth.avcd.ai`** via Kamal (`deploy-keycloak-kamal-prod.yml`), official image `quay.io/keycloak/keycloak`, secrets from Infisical **`/keycloak`** (prod). No `KC_*` GitHub secrets — OIDC variables only on the `production` environment.

`config/avcd-realm.prod.json` is **deprecated** (reference only). Keep local JSON aligned with Terraform when adding clients for local dev.

To capture Admin UI changes back to git:

```bash
./scripts/export-realm.sh
```

## Integration checklist (follow-up)

| Service | Change |
|---------|--------|
| `api` | Add Keycloak JWKS validation (same RS256 pattern as Auth0) |
| `web` | OIDC client pointing at `avcd-web` |
| `mcp` | Public PKCE client `avcd-mcp` |
| `traefik` | Route `auth.dev.avcd.ai` to Keycloak (via deploy compose labels) |

## Production deployment (Kamal)

Bootstrap order is documented in [`pulumi-infra/README.md`](../pulumi-infra/README.md) (Keycloak bootstrap section).

```bash
# After pulumi-infra stacks and Infisical /keycloak are populated:
gh workflow run deploy-keycloak-kamal-prod.yml -R Avocado-Technology/keycloak -f kamal_command=setup
gh workflow run deploy-keycloak-kamal-prod.yml -R Avocado-Technology/keycloak -f kamal_command=deploy
bash ../pulumi-infra/tests/e2e/verify-keycloak-deploy.sh
```

GitHub **variables** on `production`: `INFISICAL_OIDC_IDENTITY_ID`, `INFISICAL_INFRA_PROJECT_ID`, `INFISICAL_API_URL`, `INFISICAL_SECRET_PATH=/keycloak`, `INFISICAL_OIDC_AUDIENCE`. SSH key comes from Infisical `/ci-bootstrap` (`DO_DEPLOY_SSH_KEY`), not GitHub Secrets.

`deploy-keycloak-kamal-dev.yml` is **workflow_dispatch only** (legacy dev host disabled).

## Troubleshooting

**Port 8080 in use**

```bash
lsof -i :8080
```

**Realm not imported**

```bash
make clean && make up
docker compose logs keycloak | tail -50
```

**Password grant disabled**

The `avcd-validation` client enables direct access grants for local/CI only. Do not enable this in production clients.

## Requirements

- Docker Desktop (or Docker Engine + Compose v2)
- `curl`, `jq`, `python3`
- ~4 GB RAM for Keycloak startup
