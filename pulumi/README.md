# avcd-keycloak (Pulumi)

Syncs Keycloak Kamal deploy secrets into Infisical `/keycloak` from [`pulumi-infra`](../../pulumi-infra) `infra` stack outputs.

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

## CI

[`../.github/workflows/sync-infisical-secrets.yml`](../.github/workflows/sync-infisical-secrets.yml) — manual `workflow_dispatch` or `workflow_call` from deploy.

Seed GitHub secrets on `Avocado-Technology/keycloak`:

```bash
bash scripts/seed-github-secrets.sh
```

## State migration

If migrating from `organization/avcd-infra/keycloak-secrets`, see [docs/STATE_MIGRATION.md](docs/STATE_MIGRATION.md).

## Verify

```bash
bash ../tests/e2e/verify-infisical-keycloak.sh
```
