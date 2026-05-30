---
name: keycloak-local
description: Local Docker setup and validation for self-hosted Keycloak IdP in the AVCD keycloak repo
---

# Keycloak Local Development

> **Related**: [Auth0 Terraform Setup](~/.cursor/skills/terraform-auth0-setup/SKILL.md) | [API JWT Auth](../../api/docs/architecture/JWT_AUTH.md)

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

## References

- [Keycloak Docker guide](https://www.keycloak.org/server/containers)
- [Realm import](https://www.keycloak.org/server/importExport)
