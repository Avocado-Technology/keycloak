/** OIDC URL allowlists for the avcd-web confidential client (Auth.js / NextAuth). */

export const WEB_CLIENT_ID = "avcd-web";
export const WEB_AUTH_CALLBACK_PATH = "/api/auth/callback/keycloak";

/** Environment host prefixes on avcd.ai (dev.avcd.ai, prod.avcd.ai). */
export const DEFAULT_WEB_ENV_PREFIXES = ["dev", "prod"] as const;

function httpsOrigin(host: string): string {
  return `https://${host}`;
}

function envHosts(domain: string, prefixes: readonly string[]): string[] {
  return prefixes.map((p) => `${p}.${domain}`);
}

/**
 * Redirect URIs for authorization code flow.
 * Includes wildcard host paths and explicit Auth.js callback URLs.
 */
export function buildWebRedirectUris(
  domain: string,
  envPrefixes: readonly string[] = DEFAULT_WEB_ENV_PREFIXES,
): string[] {
  const hosts = [...envHosts(domain, envPrefixes), domain];
  const uris = new Set<string>([
    "http://localhost:3000/*",
    `http://localhost:3000${WEB_AUTH_CALLBACK_PATH}`,
    `http://localhost:3000/api/auth/callback`,
  ]);

  for (const host of hosts) {
    uris.add(`${httpsOrigin(host)}${WEB_AUTH_CALLBACK_PATH}`);
    uris.add(`${httpsOrigin(host)}/api/auth/callback`);
  }

  return [...uris];
}

/** CORS / Web origins for the confidential client. */
export function buildWebWebOrigins(
  domain: string,
  envPrefixes: readonly string[] = DEFAULT_WEB_ENV_PREFIXES,
): string[] {
  return [
    "http://localhost:3000",
    ...envHosts(domain, envPrefixes).map(httpsOrigin),
    httpsOrigin(domain),
  ];
}

/** Federated logout (?federated) post_logout_redirect_uri allowlist. */
export function buildWebPostLogoutRedirectUris(
  domain: string,
  envPrefixes: readonly string[] = DEFAULT_WEB_ENV_PREFIXES,
): string[] {
  const uris = new Set<string>([
    "http://localhost:3000",
    "http://localhost:3000/",
  ]);

  for (const host of [...envHosts(domain, envPrefixes), domain]) {
    uris.add(httpsOrigin(host));
    uris.add(`${httpsOrigin(host)}/`);
  }

  return [...uris];
}
