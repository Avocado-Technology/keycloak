/** Legacy hostname kept during avocado.tech cutover. */
export const LEGACY_ODOO_PUBLIC_HOST = "odoo.dev.avcd.ai";

export const DEFAULT_ODOO_PUBLIC_HOST = "odoo.dev.avocado.tech";

function normalizeOdooPublicHost(odooPublicHost: string): string {
  return odooPublicHost.replace(/^https?:\/\//, "").replace(/\/$/, "");
}

export function buildOdooRedirectUris(odooPublicHost: string): string[] {
  const uris = ["http://localhost:8069/auth_oauth/signin"];
  const host = normalizeOdooPublicHost(odooPublicHost);
  if (host) {
    uris.push(`https://${host}/auth_oauth/signin`);
  }
  if (host !== LEGACY_ODOO_PUBLIC_HOST) {
    uris.push(`https://${LEGACY_ODOO_PUBLIC_HOST}/auth_oauth/signin`);
  }
  return [...new Set(uris)];
}

export function buildOdooWebOrigins(odooPublicHost: string): string[] {
  const origins = ["http://localhost:8069"];
  const host = normalizeOdooPublicHost(odooPublicHost);
  if (host) {
    origins.push(`https://${host}`);
  }
  if (host !== LEGACY_ODOO_PUBLIC_HOST) {
    origins.push(`https://${LEGACY_ODOO_PUBLIC_HOST}`);
  }
  return [...new Set(origins)];
}
