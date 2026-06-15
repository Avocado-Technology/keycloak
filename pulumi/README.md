# avcd-keycloak (Pulumi)

Syncs Keycloak Kamal deploy secrets into Infisical `/keycloak` from [`pulumi-infra`](../../pulumi-infra) `infra` stack outputs.

Realm `avcd` (clients, scopes, Google IdP) is managed by **keycloak-config-cli** — see [`../config/realm-avcd.yaml`](../config/realm-avcd.yaml) and `make apply-config` in the repo root.

## Stacks

| Stack | Purpose |
|-------|---------|
| `secrets` | Infisical `/keycloak` catalog (KC_*, admin, deploy host, bootstrap URI) |

## Local

```bash
source ../../pulumi-infra/scripts/load-env.sh
bash scripts/pulumi-login-spaces.sh
npm ci && npm run build
pulumi stack select secrets
pulumi preview
pulumi up --yes
```

## Realm config (not Pulumi)

```bash
# From keycloak/ repo root
make apply-config          # local docker
make push-client-secrets   # sync KEYCLOAK_CLIENT_SECRET to app Infisical projects

gh workflow run pulumi-keycloak-config.yml -R Avocado-Technology/keycloak
```

## CI

| Workflow | Purpose |
|----------|---------|
| [`sync-infisical-secrets.yml`](../.github/workflows/sync-infisical-secrets.yml) | Pulumi `secrets` stack → Infisical `/keycloak` |
| [`pulumi-keycloak-config.yml`](../.github/workflows/pulumi-keycloak-config.yml) | keycloak-config-cli apply + push client secrets |

Seed GitHub secrets on `Avocado-Technology/keycloak`:

```bash
bash scripts/seed-github-secrets.sh
```

## State migration

If migrating from `organization/avcd-infra/keycloak-secrets`, see [docs/STATE_MIGRATION.md](docs/STATE_MIGRATION.md).

## Verify

```bash
bash ../tests/e2e/verify-infisical-keycloak.sh
curl -sf https://auth.avcd.ai/realms/avcd/.well-known/openid-configuration | head
```
