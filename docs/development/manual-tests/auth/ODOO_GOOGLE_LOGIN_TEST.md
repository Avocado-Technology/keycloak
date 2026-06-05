# Odoo Google Login Test

> **Type**: Manual Test  
> **Category**: Auth  
> **Prerequisites**: Odoo local-auth stack, `make local-auth-seed`, Google IdP configured (`configure-google-idp.sh`)  
> **Related**: [KEYCLOAK_GOOGLE_LOGIN_TEST.md](./KEYCLOAK_GOOGLE_LOGIN_TEST.md) | [odoo README](../../../../odoo/README.md)

## Overview

Validates Odoo `/web/login` → **Continue with Google** → Keycloak Google broker → Odoo session, aligned with the web portal flow.

## Prerequisites

- [ ] `make local-auth-up` and `make local-auth-seed` in `odoo/`
- [ ] `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` applied via `keycloak/scripts/configure-google-idp.sh`
- [ ] Google Cloud redirect URI: `http://localhost:8080/realms/avcd/broker/google/endpoint`
- [ ] Odoo user exists with email matching your Google account (or auth_oidc auto-provision)

## Test Steps

1. **Open Odoo login**
   - Navigate to `http://localhost:8069/web/login`
   - Expected: Button labeled **Continue with Google**
   - Actual: [Record during test]

2. **Start Google login**
   - Click **Continue with Google**
   - Expected: Redirect to Google (via Keycloak); authorize URL contains `kc_idp_hint=google`
   - Actual: [Record during test]

3. **Complete Google authentication**
   - Sign in with authorized Google account
   - Expected: Redirect to `http://localhost:8069/auth_oauth/signin`; land in Odoo backend
   - Actual: [Record during test]

4. **Verify session**
   - Open devtools → Application → Cookies → `session_id` present
   - Expected: `/web/session/get_session_info` returns a `uid`
   - Actual: [Record during test]

## Success Criteria

- [ ] Login button shows **Continue with Google** (not Keycloak password-first)
- [ ] OAuth authorize URL includes `kc_idp_hint=google` and scope `openid profile email`
- [ ] Odoo session established after Google sign-in

## Cleanup

- Sign out from Odoo if needed

---

**Last Run**: YYYY-MM-DD  
**Status**: [Pass | Fail | Blocked]  
**Run By**: [Name]
