#!/usr/bin/env bash
# Pull /keycloak secrets from hosted Infisical into .env.infisical (gitignored).
# Uses Infisical REST API (v4 per-secret) with fallback to GOOGLE_* in pulumi-infra/.env.
#
# Usage (from keycloak/):
#   bash scripts/pull-infisical-keycloak-env.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/.env.infisical"
INFISICAL_HOST="${INFISICAL_HOST:-https://secrets.avcd.ai}"
INFISICAL_ENV="${INFISICAL_ENV:-prod}"
INFISICAL_SECRET_PATH="${INFISICAL_SECRET_PATH:-/keycloak}"

# pulumi-infra last so GOOGLE_* and INFISICAL_* are not cleared by keycloak/.env
for f in "${ROOT}/../infisical/.env" "${ROOT}/../pulumi-infra/.env"; do
  if [[ -f "${f}" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${f}"
    set +a
  fi
done

INFISICAL_PROJECT_ID="${INFISICAL_INFRA_PROJECT_ID:-db036f0e-7452-4e17-9573-e5471b45d65f}"
PATH_ENC="$(python3 -c "from urllib.parse import quote; print(quote('${INFISICAL_SECRET_PATH}', safe=''))")"

# Keys we need for local Google IdP (also try full catalog when API allows read).
PULL_KEYS=(
  GOOGLE_CLIENT_ID
  GOOGLE_CLIENT_SECRET
)

fetch_secret_v4() {
  local key="$1"
  local resp code
  resp="$(mktemp)"
  code="$(
    curl -sS -o "${resp}" -w "%{http_code}" \
      -H "Authorization: Bearer ${INFISICAL_TOKEN}" \
      "${INFISICAL_HOST}/api/v4/secrets/${key}?projectId=${INFISICAL_PROJECT_ID}&environment=${INFISICAL_ENV}&secretPath=${PATH_ENC}"
  )"
  if [[ "${code}" == "200" ]]; then
    python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
s = d.get('secret') or d
v = s.get('secretValue') or s.get('value') or ''
if v:
    esc = str(v).replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
    print(f'{sys.argv[2]}=\"{esc}\"')
" "${resp}" "${key}"
    rm -f "${resp}"
    return 0
  fi
  rm -f "${resp}"
  return 1
}

append_env_keys_to_tmp() {
  python3 - "${OUT}.tmp" "${PULL_KEYS[@]}" <<'PY'
import os
import sys
from pathlib import Path

out = Path(sys.argv[1])
keys = sys.argv[2:]
lines = out.read_text(encoding="utf-8").splitlines() if out.exists() else []
existing = {ln.split("=", 1)[0] for ln in lines if "=" in ln}
for key in keys:
    if key in existing:
        continue
    val = os.environ.get(key, "")
    if not val:
        continue
    escaped = val.replace("\\", "\\\\").replace('"', '\\"')
    lines.append(f'{key}="{escaped}"')
out.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
PY
}

: > "${OUT}.tmp"
API_OK=0
API_FAIL=0

if [[ -n "${INFISICAL_CLIENT_ID:-}" && -n "${INFISICAL_CLIENT_SECRET:-}" ]]; then
  INFISICAL_TOKEN="$(
    bash "${ROOT}/tests/e2e/helpers/get-infisical-token.sh" 2>/dev/null | tr -d '\n\r' || true
  )"
  if [[ -z "${INFISICAL_TOKEN}" ]]; then
    echo "[WARN] Universal-auth returned empty token; using local env only." >&2
  else
    echo "[pull] Fetching ${INFISICAL_SECRET_PATH} (${INFISICAL_ENV}) from ${INFISICAL_HOST} ..."
    for key in "${PULL_KEYS[@]}"; do
      if fetch_secret_v4 "${key}" >> "${OUT}.tmp"; then
        API_OK=$((API_OK + 1))
      else
        API_FAIL=$((API_FAIL + 1))
      fi
    done
    if [[ "${API_FAIL}" -gt 0 ]]; then
      echo "[WARN] Infisical API read failed for ${API_FAIL} key(s) (HTTP 403 often means identity lacks read on /keycloak)." >&2
    fi
  fi
else
  echo "[pull] No INFISICAL_CLIENT_ID/SECRET; using local env only." >&2
fi

append_env_keys_to_tmp

KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-Admin1234!}"
{
  cat "${OUT}.tmp"
  echo ""
  echo "# Local overrides (pull-infisical-keycloak-env.sh) — not from hosted Infisical"
  echo "KEYCLOAK_URL=http://localhost:8080"
  echo "KEYCLOAK_REALM=avcd"
  echo "KEYCLOAK_ADMIN=admin"
  echo "KEYCLOAK_ADMIN_PASSWORD=${KC_ADMIN_PASSWORD}"
} > "${OUT}"
rm -f "${OUT}.tmp"
chmod 600 "${OUT}" 2>/dev/null || true

if ! grep -q '^GOOGLE_CLIENT_ID=' "${OUT}" || ! grep -q '^GOOGLE_CLIENT_SECRET=' "${OUT}"; then
  echo "[ERROR] GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET required." >&2
  echo "        Set in ../pulumi-infra/.env or sync: bash scripts/sync-local-secrets-to-infisical.sh" >&2
  exit 1
fi

SRC="local env"
[[ "${API_OK}" -gt 0 ]] && SRC="Infisical API + local env"
echo "[pull] Wrote ${OUT} (${SRC}; ${API_OK} key(s) from API)"
