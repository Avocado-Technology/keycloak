# Pulumi state migration: avcd-infra/keycloak-secrets → avcd-keycloak/secrets

One-time operator procedure after moving the Infisical `/keycloak` catalog to this repo.

## Before

| Field | Value |
|-------|--------|
| Project | `avcd-infra` |
| Stack | `keycloak-secrets` |
| Backend | `s3://avcd-infra-tfstate/pulumi?region=us-east-1&endpoint=sfo3.digitaloceanspaces.com` |

## After

| Field | Value |
|-------|--------|
| Project | `avcd-keycloak` |
| Stack | `secrets` |
| Same backend and passphrase | unchanged |

## Steps

```bash
cd keycloak/pulumi
source ../../pulumi-infra/scripts/load-env.sh   # or export SPACES_* + PULUMI_CONFIG_PASSPHRASE
bash scripts/pulumi-login-spaces.sh

# 1. Export old state
pulumi stack export --stack organization/avcd-infra/keycloak-secrets > /tmp/kc-old.json

# 2. Init new stack (if not exists)
pulumi stack init secrets --secrets-provider passphrase

# 3. Import state (may require URN edits — see below)
pulumi stack import --stack secrets < /tmp/kc-old.json

# 4. Verify no unwanted replaces
pulumi preview --stack secrets

# 5. If preview is clean, apply once
pulumi up --stack secrets --yes

# 6. Remove old stack from backend (only after step 5 succeeds)
pulumi stack rm organization/avcd-infra/keycloak-secrets --yes
```

## If preview wants to create duplicate Infisical resources

Resource URNs include the project name. After import, if Pulumi plans **create** for `infisical_secret` resources:

1. List existing secrets in Infisical UI under `/keycloak` (prod).
2. Use `pulumi import` for each resource with its Infisical ID, or
3. Run `pulumi up` on the **old** stack once to destroy, then `pulumi up` on **new** stack (brief gap — only if catalog can be republished from `infra` outputs).

Prefer import over destroy when production Keycloak depends on current values.

## URN project rename

If import fails validation, sed-replace project segment in exported JSON:

- `avcd-infra` → `avcd-keycloak` in resource URNs
- Stack name references: `keycloak-secrets` → `secrets`

Then re-run `pulumi stack import`.

## CI

After migration, use **Sync Infisical secrets** workflow (`sync-infisical-secrets.yml`) with command `up` instead of pulumi-infra `keycloak-secrets.yml`.
