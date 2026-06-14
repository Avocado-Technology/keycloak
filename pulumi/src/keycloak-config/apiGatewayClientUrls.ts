export const DEFAULT_API_GATEWAY_PUBLIC_HOST = "dev.avocado.tech";
export const DEFAULT_API_GATEWAY_PUBLIC_PATH = "/api-gateway";

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

/** Public base URL for AVCD API Gateway (path prefix on shared dev host). */
export function buildApiGatewayPublicUrl(
  publicHost: string,
  publicPath: string = DEFAULT_API_GATEWAY_PUBLIC_PATH,
): string {
  const host = normalizePublicHost(publicHost);
  const path = normalizePublicPath(publicPath);
  const resolvedHost = host || DEFAULT_API_GATEWAY_PUBLIC_HOST;
  return path ? `https://${resolvedHost}${path}` : `https://${resolvedHost}`;
}

/** JWT audience for AVCD API Gateway tokens. */
export function buildApiGatewayAudience(
  publicHost: string,
  publicPath: string = DEFAULT_API_GATEWAY_PUBLIC_PATH,
): string {
  return buildApiGatewayPublicUrl(publicHost, publicPath);
}

/** GraphQL endpoint URL for federated queries. */
export function buildApiGatewayGraphqlUrl(
  publicHost: string,
  publicPath: string = DEFAULT_API_GATEWAY_PUBLIC_PATH,
): string {
  return `${buildApiGatewayPublicUrl(publicHost, publicPath)}/`;
}
