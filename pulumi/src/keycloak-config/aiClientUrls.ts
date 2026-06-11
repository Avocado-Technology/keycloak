export const DEFAULT_AI_PUBLIC_HOST = "ai.dev.avocado.tech";

function normalizeAiPublicHost(aiPublicHost: string): string {
  return aiPublicHost.replace(/^https?:\/\//, "").replace(/\/$/, "");
}

export function buildAiRedirectUris(aiPublicHost: string): string[] {
  const uris = [
    "http://localhost:3080/oauth/openid/callback",
    "http://localhost:3080/api/admin/oauth/openid/callback",
  ];
  const host = normalizeAiPublicHost(aiPublicHost);
  if (host) {
    uris.push(`https://${host}/oauth/openid/callback`);
    uris.push(`https://${host}/api/admin/oauth/openid/callback`);
  }
  return [...new Set(uris)];
}

export function buildAiWebOrigins(aiPublicHost: string): string[] {
  const origins = ["http://localhost:3080"];
  const host = normalizeAiPublicHost(aiPublicHost);
  if (host) {
    origins.push(`https://${host}`);
  }
  return [...new Set(origins)];
}

/** Post-logout redirect URIs for LibreChat end-session (lands on /login?redirect=false). */
export function buildAiPostLogoutRedirectUris(aiPublicHost: string): string[] {
  const uris = new Set<string>(["http://localhost:3080/login"]);
  const host = normalizeAiPublicHost(aiPublicHost);
  if (host) {
    uris.add(`https://${host}/login`);
  }
  return [...uris];
}
