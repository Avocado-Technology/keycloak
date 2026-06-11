export const DEFAULT_CONTA_AZUL_PUBLIC_HOST = "dev.avocado.tech";
export const DEFAULT_CONTA_AZUL_PUBLIC_PATH = "/conta-azul-service";
export const CONTA_AZUL_API_CLIENT_ID = "avcd-conta-azul-api";

function normalizePublicHost(publicHost: string): string {
  return publicHost.replace(/^https?:\/\//, "").replace(/\/$/, "");
}

function normalizePublicPath(publicPath: string): string {
  const trimmed = publicPath.trim();
  if (!trimmed || trimmed === "/") {
    return "";
  }
  const withLeading = trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
  return withLeading.replace(/\/$/, "");
}

/** Public base URL for Conta Azul Service (path prefix on shared dev host). */
export function buildContaAzulPublicUrl(
  publicHost: string,
  publicPath: string = DEFAULT_CONTA_AZUL_PUBLIC_PATH,
): string {
  const host = normalizePublicHost(publicHost);
  const path = normalizePublicPath(publicPath);
  const resolvedHost = host || DEFAULT_CONTA_AZUL_PUBLIC_HOST;
  return path ? `https://${resolvedHost}${path}` : `https://${resolvedHost}`;
}

/** JWT audience for Conta Azul Service API tokens. */
export function buildContaAzulAudience(
  publicHost: string,
  publicPath: string = DEFAULT_CONTA_AZUL_PUBLIC_PATH,
): string {
  return buildContaAzulPublicUrl(publicHost, publicPath);
}

/** GraphQL endpoint URL for MCP and integrations. */
export function buildContaAzulGraphqlUrl(
  publicHost: string,
  publicPath: string = DEFAULT_CONTA_AZUL_PUBLIC_PATH,
): string {
  return `${buildContaAzulPublicUrl(publicHost, publicPath)}/graphql`;
}
