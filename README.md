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

Realm settings are imported from `config/avcd-realm.json` on first boot (`--import-realm`).

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
| `traefik` | Route `auth.dev.avcd.ai` to Keycloak |

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
