# AVCD Keycloak

Self-hosted [Keycloak](https://www.keycloak.org/) identity provider for the AVCD platform. Local-first Docker stack to validate OIDC/OAuth2 before integrating with web, API, and MCP services.

## Shared identity platform (infra only)

Same model as **Infisical**: one deployment on the **infra** stack; every application environment uses it **by URL**.

| Platform | Deployed once on infra | Consumed by dev / prod |
|----------|------------------------|-------------------------|
| **Infisical** | `https://secrets.avcd.ai` | Each app’s Infisical project + OIDC at deploy time |
| **Keycloak** | `https://auth.avcd.ai` | `KEYCLOAK_URL` / issuer `https://auth.avcd.ai/realms/avcd` |

There is **no** separate Keycloak host for “dev” (no `auth.dev.avcd.ai` deploy). `make up` is local-only. Kamal deploy runs from `deploy-keycloak-kamal-prod.yml` (workflow name says “infra”; GitHub `production` environment is OIDC binding only).

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

Shared Keycloak runs at **`https://auth.avcd.ai`** via Kamal (`deploy-keycloak-kamal-prod.yml`), official image `quay.io/keycloak/keycloak`, deploy secrets from Infisical **`/keycloak`** (written by this repo’s [`pulumi/`](pulumi/) stack `avcd-keycloak/secrets` via [`sync-infisical-secrets.yml`](.github/workflows/sync-infisical-secrets.yml); Infisical env slug `prod` = infra host catalog, not a second IdP). No `KC_*` GitHub secrets — OIDC variables on the `production` GitHub environment for CI only.

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
| `api`, `web`, `mcp` | Set issuer/JWKS to `https://auth.avcd.ai/realms/avcd` (dev and prod deploys) |
| `traefik` | `auth.avcd.ai` → Keycloak container on `avcd_edge` (Kamal labels in `config/deploy.yml`) |

## Production deployment (Kamal)

### Bootstrap order

1. **pulumi-infra** — `pulumi up --stack infra` (Keycloak DB, DNS `auth.avcd.ai`, stack outputs). See [`pulumi-infra/README.md`](../pulumi-infra/README.md).
2. **This repo** — sync Infisical `/keycloak` (reads infra outputs via Pulumi stack reference).
3. **This repo** — Kamal deploy (OIDC read from Infisical).

```bash
# One-time: GitHub secrets for Pulumi sync on keycloak repo
cd pulumi && bash scripts/seed-github-secrets.sh

# After infra is up: populate /keycloak (first time or after credential rotation)
gh workflow run sync-infisical-secrets.yml -R Avocado-Technology/keycloak -f pulumi_command=up

# Verify catalog
bash tests/e2e/verify-infisical-keycloak.sh

# Deploy (optional: sync + deploy in one dispatch)
gh workflow run deploy-keycloak-kamal-prod.yml -R Avocado-Technology/keycloak \
  -f kamal_command=setup -f sync_infisical_first=true
gh workflow run deploy-keycloak-kamal-prod.yml -R Avocado-Technology/keycloak -f kamal_command=deploy

bash ../pulumi-infra/tests/e2e/verify-keycloak-deploy.sh
```

Pulumi project lives in [`pulumi/`](pulumi/). State migration from `pulumi-infra/keycloak-secrets`: [`pulumi/docs/STATE_MIGRATION.md`](pulumi/docs/STATE_MIGRATION.md).

**GitHub secrets**

| Secret | Workflow | Purpose |
|--------|----------|---------|
| `SPACES_ACCESS_KEY_ID`, `SPACES_SECRET_ACCESS_KEY`, `PULUMI_CONFIG_PASSPHRASE`, `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET` | `sync-infisical-secrets.yml` | Pulumi → Infisical `/keycloak` |
| `GH_INFRA_TOKEN` | `deploy-keycloak-kamal-prod.yml` | Checkout private `Avocado-Technology/avcd-actions` (pinned commit `2e0e1b5`) |

**GitHub variables** on `production` (deploy OIDC): `INFISICAL_OIDC_IDENTITY_ID`, `INFISICAL_INFRA_PROJECT_ID`, `INFISICAL_API_URL`, `INFISICAL_SECRET_PATH=/keycloak`, `INFISICAL_ENV=prod`, `INFISICAL_OIDC_AUDIENCE=https://secrets.avcd.ai`, optional `KAMAL_VERSION=2.11.0`. SSH and DB secrets come from Infisical (`/keycloak`, `/ci-bootstrap`), not GitHub Secrets.

**Registry:** Kamal builds the wrapper `Dockerfile` and pushes to `localhost:5555` on the infra droplet (no DOCR login in CI). Post-deploy CI checks OIDC discovery at `https://<KEYCLOAK_HOST>/realms/avcd/.well-known/openid-configuration`.

Optional Google IdP secrets: `bash scripts/sync-local-secrets-to-infisical.sh` with `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` set.

Post-deploy locally: `KEYCLOAK_HOST=auth.avcd.ai make e2e-deploy`

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
