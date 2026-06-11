export const DEFAULT_FRAPPE_PUBLIC_HOST = "dev.avocado.tech";

const FRAPPE_OAUTH_CALLBACK_PATH =
  "/api/method/frappe.integrations.oauth2_logins.custom/google";
const FRAPPE_OAUTH_CALLBACK_PATH_LEGACY =
  "/api/method/frappe.integrations.oauth2.login_via_oauth2";

function normalizeFrappePublicHost(frappePublicHost: string): string {
  return frappePublicHost.replace(/^https?:\/\//, "").replace(/\/$/, "");
}

export function buildFrappeRedirectUris(frappePublicHost: string): string[] {
  const uris = [
    `http://localhost:8080${FRAPPE_OAUTH_CALLBACK_PATH}`,
    `http://localhost:8080${FRAPPE_OAUTH_CALLBACK_PATH_LEGACY}`,
    `http://localhost:8088${FRAPPE_OAUTH_CALLBACK_PATH}`,
    `http://localhost:8088${FRAPPE_OAUTH_CALLBACK_PATH_LEGACY}`,
  ];
  const host = normalizeFrappePublicHost(frappePublicHost);
  if (host) {
    uris.push(`https://${host}${FRAPPE_OAUTH_CALLBACK_PATH}`);
    uris.push(`https://${host}${FRAPPE_OAUTH_CALLBACK_PATH_LEGACY}`);
  }
  return [...new Set(uris)];
}

export function buildFrappeWebOrigins(frappePublicHost: string): string[] {
  const origins = ["http://localhost:8080"];
  const host = normalizeFrappePublicHost(frappePublicHost);
  if (host) {
    origins.push(`https://${host}`);
  }
  return [...new Set(origins)];
}
