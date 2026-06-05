# Odoo Google Login (dev)

> **Type**: Manual Test  
> **Category**: Auth  
> **Prerequisites**: `keycloak-config` + `odoo-secrets` applied; Kamal deploy + post-deploy OIDC configure completed  
> **Related**: [ODOO_GOOGLE_LOGIN_TEST](./ODOO_GOOGLE_LOGIN_TEST.md) | [odoo-authentication skill](../../../../../avcd-odoo/.cursor/skills/security/odoo-authentication/SKILL.md)

## Overview

Validates Google SSO on `https://odoo.dev.avcd.ai` via Keycloak broker (`kc_idp_hint=google`).

## Prerequisites

- [ ] `bash tests/e2e/verify-odoo-app-dev.sh` passes with `ODOO_URL=https://odoo.dev.avcd.ai`
- [ ] Google OAuth client allows Keycloak broker redirect for prod Keycloak (if testing real Google)

## Test Steps

1. **Open login**: Navigate to `https://odoo.dev.avcd.ai/web/login`
   - Expected: **Continue with Google** button visible

2. **Start OAuth**: Click **Continue with Google**
   - Expected: Redirect to `https://auth.avcd.ai/realms/avcd/...` with `client_id=avcd-odoo`, `scope` containing `profile`, `kc_idp_hint=google`

3. **Complete Google login** (use a test Google account allowed in Keycloak)
   - Expected: Return to Odoo; land in backend `/odoo` as **internal** user (not portal-only)

4. **Session**: Refresh `/odoo`
   - Expected: Still authenticated

## Success Criteria

- [ ] SSO surface checks pass in `verify-odoo-app-dev.sh`
- [ ] User can access Odoo backend after Google login
- [ ] User has internal access (`base.group_user`), not portal-only

## Cleanup

- Remove test user from Odoo if created solely for this test.

---

**Last Run**: —  
**Status**: —  
**Run By**: —
