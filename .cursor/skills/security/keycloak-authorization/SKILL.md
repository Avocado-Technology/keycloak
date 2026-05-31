---
name: keycloak-authorization
description: Keycloak user permissions and authorization — roles/groups (RBAC) vs Authorization Services (fine-grained resources, scopes, policies, RPT). Covers AVCD avcd realm setup, token claims, and integration with api/web/mcp.
---

# Keycloak User Permissions & Authorization

> **Related**: [keycloak-local](./keycloak-local/SKILL.md) | [terraform-keycloak](../../../infra/.cursor/skills/terraform-keycloak/SKILL.md) | [terraform-auth0-setup](~/.cursor/skills/terraform-auth0-setup/SKILL.md) | [API Architecture](../../../api/.cursor/skills/api-architecture/SKILL.md)

## Overview

Keycloak is an **identity and access management (IAM)** platform. It handles both:

| Concern | Official term | What it answers |
|---------|---------------|-----------------|
| **Authentication** | AuthN | Who is this user? |
| **Authorization** | AuthZ | What can this user access or do? |

Keycloak can manage user permissions at **two levels**. Choose based on how fine-grained access control must be.

---

## Level 1: Roles & Groups (RBAC) — recommended starting point

From the [Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/):

### Core concepts

| Concept | Description |
|---------|-------------|
| **Roles** | Categories of user (`admin`, `user`, `manager`). Apps grant access by role, not per-user. |
| **User role mapping** | Assign roles to users; mappings can be embedded in tokens. |
| **Composite roles** | A role that inherits other roles (e.g. `superuser` → `sales-admin` + `order-entry-admin`). |
| **Groups** | Collections of users; groups can have attributes and role mappings members inherit. |
| **Client roles** | Role namespace scoped to a specific OIDC client. |
| **Token mappers** | Map roles, attributes, and scopes into JWT claims so apps enforce access. |

Official guidance:

> *"Applications often assign access and permissions to specific roles rather than individual users."*

> *"Token mappers — Map user attributes, roles, etc. how you want into tokens and assertions so that applications can decide access permissions on various resources they manage."*

### How apps enforce

1. User authenticates via Keycloak (OIDC).
2. Access token includes roles/scopes as claims (via protocol mappers).
3. **Resource server** (`api`, `web` BFF, `mcp`) validates JWT and checks roles/scopes locally.

Example API pattern (mirrors Auth0 `read`/`write` scopes):

```python
# api — check realm role or custom claim from token
if "admin" not in token.realm_roles:
    raise Forbidden("Insufficient permissions")
```

### AVCD current setup (`config/avcd-realm.json`)

| Item | Value |
|------|-------|
| Realm | `avcd` |
| Default realm role | `user` |
| API audience scope | `avcd-api-audience` → `https://dev.avcd.ai/api` |
| MCP audience scope | `avcd-mcp-audience` → `https://dev.avcd.ai/mcp` |

**What we have today:** authentication + audience claims + a single realm role. **Not yet:** client roles, groups, or Authorization Services.

### Managing roles in Keycloak

**Admin Console:** Realm → Users → select user → Role mapping  
**Admin Console:** Realm → Realm roles / Groups  
**Realm JSON:** `roles.realm`, `users[].realmRoles` in `config/avcd-realm.json`  
**Terraform:** `keycloak_role`, `keycloak_user_roles`, `keycloak_group` (see [terraform-keycloak](../../../infra/.cursor/skills/terraform-keycloak/SKILL.md))

### Export role changes to git

```bash
./scripts/export-realm.sh
git diff config/avcd-realm.json
```

---

## Level 2: Authorization Services — fine-grained permissions

From the [Authorization Services Guide](https://www.keycloak.org/docs/latest/authorization_services/):

Use when you need **centralized, resource-level, policy-driven** access — not just "user has role X."

### Architecture (official)

| Component | Role |
|-----------|------|
| **PAP** (Policy Administration Point) | Admin Console + Protection API — define resources, policies, permissions |
| **PDP** (Policy Decision Point) | Evaluates policies when apps request authorization |
| **PEP** (Policy Enforcement Point) | App-side enforcer that asks Keycloak and blocks/allows access |
| **PIP** (Policy Information Point) | User attributes, context (IP, time, groups) used during evaluation |

### Key concepts

| Concept | Meaning | Example |
|---------|---------|---------|
| **Resource** | Protected object | `/teams`, `store-123`, GraphQL mutation |
| **Scope** | Action on a resource | `read`, `write`, `delete`, `approve` |
| **Policy** | Rule (conditions for access) | Role-based, user-based, time-based, JS, aggregated |
| **Permission** | Links resource + scope + policy | "Users with `team-admin` can `view`,`create` on `teams`" |

Formal model (official):

```
X CAN DO Y ON RESOURCE Z
```

- **X** — user, role, group, or claim
- **Y** — scope (action)
- **Z** — protected resource

### Supported access control models

Keycloak officially supports:

- **RBAC** — role-based access control
- **ABAC** — attribute-based access control
- **UBAC** — user-based access control
- **CBAC** — context-based access control (IP, time, client)
- **Rule-based** — JavaScript policies
- **Time-based** — access windows
- **Custom** — via SPI

### Requesting Party Token (RPT)

When Authorization Services is enabled:

1. User gets a normal OIDC access token (authentication).
2. App sends an **authorization request** to the token endpoint (`grant_type=urn:ietf:params:oauth:grant-type:uma-ticket`).
3. Keycloak evaluates policies for requested resource(s) and scope(s).
4. Keycloak returns an **RPT** — a JWT containing granted permissions.
5. Resource server enforces based on RPT claims.

Discovery endpoint:

```
GET /realms/{realm}/.well-known/uma2-configuration
```

### Enabling Authorization Services on a client

1. Admin Console → **Clients** → select client (must be confidential for resource server)
2. **Capability config** → **Authorization Enabled** = ON
3. Configure tabs: **Resources**, **Authorization Scopes**, **Policies**, **Permissions**
4. Use **Evaluate** tab to simulate authorization requests

Policy types include: Role, User, Group, Client, Time, Regex, JavaScript, Aggregated.

### Policy enforcement modes

| Mode | Behavior |
|------|----------|
| **Enforcing** (default) | Deny if no policy matches |
| **Permissive** | Allow if no policy matches |
| **Disabled** | Skip policy evaluation |

---

## Choosing the right level for AVCD

| Requirement | Use | AVCD status |
|-------------|-----|-------------|
| User is logged in | OIDC authentication | Planned / local dev |
| Token targets correct API (`aud`) | Client scopes + audience mappers | ✅ `avcd-realm.json` |
| Coarse roles (`admin`, `user`) | Realm/client roles in JWT | ✅ `user` role only |
| API scopes like Auth0 `read`/`write` | Realm roles or custom scopes in token | ❌ Not yet (Auth0 has this) |
| Per-tenant / per-store permissions | Authorization Services or app DB + roles | ❌ Not configured |
| Permissions change without API redeploy | Authorization Services + RPT | ❌ Not configured |
| User-managed sharing (UMA) | Authorization Services + UMA | ❌ Not configured |

**Recommendation:** Start with **Level 1 (roles + scopes in JWT)** to parity Auth0 resource-server scopes. Add **Authorization Services** only if you need resource-instance permissions (e.g. "user X can write store Y but read store Z") managed centrally in Keycloak.

---

## Integration with AVCD services

### API (`api/`)

- Validate JWT (issuer, audience, signature) — same RS256 pattern as Auth0.
- Read roles/scopes from token claims; enforce in service layer (`shared.permissions`, Casbin if used).
- For Authorization Services: optionally validate RPT or call token introspection endpoint.

```python
jwks_uri = f"{settings.keycloak_url}/realms/avcd/protocol/openid-connect/certs"
issuer = f"{settings.keycloak_url}/realms/avcd"
# Expect audience: https://dev.avcd.ai/api
```

### Web (`web/`)

- OIDC login via `avcd-web` client.
- Roles available in session/token for UI gating (hide admin nav, etc.).
- Do not rely on UI-only checks — API must enforce.

### MCP (`mcp/`)

- Public PKCE client `avcd-mcp`; audience `https://dev.avcd.ai/mcp`.
- OAuth scopes/roles in token determine tool access if needed.

### Auth0 migration note

| Auth0 | Keycloak equivalent |
|-------|---------------------|
| Resource server + scopes (`read`, `write`) | Realm/client roles or custom client scopes in JWT |
| Management API permissions | `realm-management` client roles |
| Fine-grained RBAC in Actions/Rules | Authorization Services policies |

Preserve audience URLs when migrating so downstream services change minimally.

---

## What Keycloak does NOT do

| Limitation | Detail |
|------------|--------|
| **Apps still enforce** | Keycloak issues tokens/permissions; `api`/`web`/`mcp` must validate and act |
| **Runtime user data ≠ Terraform** | User accounts and live role assignments are via Admin Console, REST API, or LDAP — not typical Terraform day-to-day |
| **Authorization Services is opt-in** | Not enabled by default; separate from basic realm roles |
| **Config ≠ user database backup** | Back up Postgres separately; realm export does not replace DB backups |

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Roles missing from JWT | Add realm/client role mappers to client scopes; ensure roles assigned to user |
| API rejects token (403) | Check `aud` claim matches `https://dev.avcd.ai/api`; verify audience scope is default on client |
| Authorization Services 403 | Check policies, permissions, enforcement mode; use Evaluate tab in Admin Console |
| `realm-management` roles for automation | Assign via Service Account Roles on Terraform client — see terraform-keycloak skill |
| Role changes not in git | Run `./scripts/export-realm.sh` after Admin Console edits |

---

## References

- [Server Admin Guide — roles, groups, user role mapping](https://www.keycloak.org/docs/latest/server_admin/)
- [Authorization Services Guide — overview](https://www.keycloak.org/docs/latest/authorization_services/)
- [Managing permissions](https://www.keycloak.org/docs/latest/authorization_services/#_managing_permissions)
- [Obtaining permissions / RPT](https://www.keycloak.org/docs/latest/authorization_services/#_service_overview)
- [Policy types (Role, User, Group, Time, JS)](https://www.keycloak.org/docs/latest/authorization_services/#_managing_policies)
- AVCD realm seed: `config/avcd-realm.json`
- AVCD Terraform config: `infra/.cursor/skills/terraform-keycloak/SKILL.md`
