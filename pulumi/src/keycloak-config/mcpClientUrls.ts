export const DEFAULT_MCP_PUBLIC_HOST = "dev.avocado.tech";

function normalizePublicHost(publicHost: string): string {
  return publicHost.replace(/^https?:\/\//, "").replace(/\/$/, "");
}

/** Public MCP base URL (path prefix on shared dev host). */
export function buildMcpPublicUrl(
  publicHost: string = DEFAULT_MCP_PUBLIC_HOST,
): string {
  const host = normalizePublicHost(publicHost) || DEFAULT_MCP_PUBLIC_HOST;
  return `https://${host}/mcp`;
}

/** OAuth redirect URIs for avcd-mcp (PKCE) — includes legacy dev.avcd.ai and dev.avocado.tech. */
export function buildMcpRedirectUris(
  mcpPublicHost: string,
  domain: string,
): string[] {
  const host = normalizePublicHost(mcpPublicHost) || DEFAULT_MCP_PUBLIC_HOST;
  return [
    "http://localhost:3001/mcp/oauth/callback",
    "http://localhost:3001/callback",
    `https://dev.${domain}/mcp/oauth/callback`,
    `https://dev.${domain}/callback`,
    `https://${host}/mcp/oauth/callback`,
    `https://${host}/callback`,
    "https://claude.ai/api/mcp/auth_callback",
    "https://claude.com/api/mcp/auth_callback",
  ];
}

export function buildMcpWebOrigins(
  mcpPublicHost: string,
  domain: string,
): string[] {
  const host = normalizePublicHost(mcpPublicHost) || DEFAULT_MCP_PUBLIC_HOST;
  return [
    "http://localhost:3001",
    `https://dev.${domain}`,
    `https://${domain}`,
    `https://${host}`,
  ];
}
