#!/usr/bin/env bash
# Validates Google identity provider structure in realm import JSON files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_cmd jq

validate_realm_google_idp() {
  local file="$1"
  [[ -f "$file" ]] || fail "$file missing"

  local count
  count="$(jq '[.identityProviders[]? | select(.providerId == "google")] | length' "$file")"
  [[ "$count" -eq 1 ]] || fail "$file must define exactly one google identity provider"

  jq -e '.identityProviders[] | select(.alias == "google" and .enabled == true)' "$file" >/dev/null \
    || fail "$file google IdP must be enabled with alias google"

  local client_id
  client_id="$(jq -r '.identityProviders[] | select(.providerId == "google") | .config.clientId' "$file")"
  [[ -n "$client_id" ]] || fail "$file google IdP missing config.clientId"

  local sync_mode
  sync_mode="$(jq -r '.identityProviders[] | select(.providerId == "google") | .config.syncMode' "$file")"
  [[ "$sync_mode" == "IMPORT" ]] || fail "$file google IdP syncMode must be IMPORT"

  pass "$(basename "$file") google IdP structure"
}

validate_realm_google_idp "config/avcd-realm.json"
validate_realm_google_idp "config/avcd-realm.prod.json"

echo "All realm Google IdP checks passed."
