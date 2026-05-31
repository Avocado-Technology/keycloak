# Keycloak Google Login Test

> **Type**: Manual Test  
> **Category**: Auth  
> **Prerequisites**: Keycloak running with Google IdP configured (`configure-google-idp.sh`), web app using Keycloak auth  
> **Related**: [keycloak-local SKILL](../../../../.cursor/skills/security/keycloak-local/SKILL.md)

## Overview

Validates the complete browser flow: user clicks Continue with Google, authenticates via Google through Keycloak, and receives a session with a valid API access token.

## Prerequisites

- [ ] Google Cloud Console has Keycloak broker redirect URIs:
  - Local: `http://localhost:8080/realms/avcd/broker/google/endpoint`
  - Dev: `https://auth.dev.avcd.ai/realms/avcd/broker/google/endpoint`
- [ ] `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` set in Infisical `/keycloak` or local `.env`
- [ ] `./scripts/configure-google-idp.sh` completed successfully
- [ ] Web app configured with `KEYCLOAK_*` env vars

## Test Steps

1. **Open web app login**
   - Navigate to `http://localhost:3000` (local) or `https://dev.avcd.ai` (dev)
   - Expected: Login gate with Continue with Google
   - Actual: [Record during test]

2. **Start Google login**
   - Click Continue with Google
   - Expected: Redirect to Google sign-in (via Keycloak broker)
   - Actual: [Record during test]

3. **Complete Google authentication**
   - Sign in with a Google account authorized for the OAuth client
   - Expected: Redirect back to app callback; user lands on authenticated home page
   - Actual: [Record during test]

4. **Verify GraphQL access**
   - Open browser devtools → Network → find GraphQL request
   - Expected: `Authorization: Bearer` header present; GraphQL returns data (not UNAUTHENTICATED)
   - Actual: [Record during test]

5. **Verify logout**
   - Click Sign out
   - Expected: Session cleared; Google session ended (re-login does not skip Google prompt)
   - Actual: [Record during test]

## Success Criteria

- [ ] Google login completes without redirect_uri_mismatch
- [ ] Access token audience is `https://dev.avcd.ai/api`
- [ ] GraphQL queries succeed after login
- [ ] Logout clears app and federated Google session

## Cleanup

- Sign out from the web app if still logged in

---

**Last Run**: YYYY-MM-DD  
**Status**: [Pass | Fail | Blocked]  
**Run By**: [Name]
