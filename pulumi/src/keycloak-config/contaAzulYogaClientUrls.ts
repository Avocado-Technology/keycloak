export const DEFAULT_CONTA_AZUL_YOGA_PUBLIC_HOST = "dev.avocado.tech";
export const DEFAULT_CONTA_AZUL_YOGA_PUBLIC_PATH = "/conta-azul-yoga-subgraph";

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

/** Public base URL for Conta Azul Yoga Subgraph (path prefix on shared dev host). */
export function buildContaAzulYogaPublicUrl(
  publicHost: string,
  publicPath: string = DEFAULT_CONTA_AZUL_YOGA_PUBLIC_PATH,
): string {
  const host = normalizePublicHost(publicHost);
  const path = normalizePublicPath(publicPath);
  const resolvedHost = host || DEFAULT_CONTA_AZUL_YOGA_PUBLIC_HOST;
  return path ? `https://${resolvedHost}${path}` : `https://${resolvedHost}`;
}

/** JWT audience for Conta Azul Yoga Subgraph API tokens. */
export function buildContaAzulYogaAudience(
  publicHost: string,
  publicPath: string = DEFAULT_CONTA_AZUL_YOGA_PUBLIC_PATH,
): string {
  return buildContaAzulYogaPublicUrl(publicHost, publicPath);
}

/** GraphQL endpoint URL for integrations. */
export function buildContaAzulYogaGraphqlUrl(
  publicHost: string,
  publicPath: string = DEFAULT_CONTA_AZUL_YOGA_PUBLIC_PATH,
): string {
  return `${buildContaAzulYogaPublicUrl(publicHost, publicPath)}/graphql`;
}
