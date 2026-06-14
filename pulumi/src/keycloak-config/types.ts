import * as pulumi from "@pulumi/pulumi";
import * as keycloak from "@pulumi/keycloak";
import { DEFAULT_AI_PUBLIC_HOST } from "./aiClientUrls";
import {
  buildContaAzulAudience,
  DEFAULT_CONTA_AZUL_PUBLIC_HOST,
  DEFAULT_CONTA_AZUL_PUBLIC_PATH,
} from "./contaAzulClientUrls";
import {
  buildContaAzulYogaAudience,
  DEFAULT_CONTA_AZUL_YOGA_PUBLIC_HOST,
  DEFAULT_CONTA_AZUL_YOGA_PUBLIC_PATH,
} from "./contaAzulYogaClientUrls";
import { DEFAULT_FRAPPE_PUBLIC_HOST } from "./frappeClientUrls";
import { DEFAULT_ODOO_PUBLIC_HOST } from "./odooClientUrls";

export const REALM_NAME = "avcd";
export const WEB_OIDC_AUTHORIZATION_SCOPE = "openid profile email";
export const GOOGLE_IDP_ALIAS = "google";
/** Realm role for LibreChat (avcd-ai); never auto-assigned — grant manually in Keycloak Admin. */
export const AI_ACCESS_REALM_ROLE = "avcd-ai-access";

export interface KeycloakConfigArgs {
  provider: keycloak.Provider;
  domain: string;
  /** Public Odoo hostname (FQDN), e.g. odoo.dev.avocado.tech */
  odooPublicHost?: string;
  /** Public LibreChat hostname (FQDN), e.g. ai.dev.avocado.tech */
  aiPublicHost?: string;
  /** Public Frappe hostname (FQDN), e.g. frappe.dev.avcd.ai */
  frappePublicHost?: string;
  /** Public Conta Azul Service hostname (FQDN), e.g. dev.avocado.tech */
  contaAzulPublicHost?: string;
  /** Traefik path prefix on shared host, e.g. /conta-azul-service */
  contaAzulPublicPath?: string;
  /** Public Conta Azul Yoga Subgraph hostname (FQDN), e.g. dev.avocado.tech */
  contaAzulYogaPublicHost?: string;
  /** Traefik path prefix for yoga subgraph, e.g. /conta-azul-yoga-subgraph */
  contaAzulYogaPublicPath?: string;
  /** Public MCP hostname (FQDN), e.g. dev.avocado.tech — path is always /mcp */
  mcpPublicHost?: string;
  keycloakUrl: string;
  apiAudience?: string;
  mcpAudience?: string;
  enableGoogleIdentityProvider?: boolean;
  googleClientId?: string;
  googleClientSecret?: string;
  includeLocalhostGoogleRedirectUri?: boolean;
  /** When unset, KeycloakConfig generates a stable RandomPassword. */
  odooClientSecret?: pulumi.Input<string>;
  /** When unset, KeycloakConfig generates a stable RandomPassword. */
  aiClientSecret?: pulumi.Input<string>;
  /** When unset, KeycloakConfig generates a stable RandomPassword. */
  frappeClientSecret?: pulumi.Input<string>;
  /** When unset, KeycloakConfig generates a stable RandomPassword. */
  contaAzulApiClientSecret?: pulumi.Input<string>;
}

export interface ResolvedAudiences {
  apiAudience: string;
  mcpAudience: string;
  contaAzulAudience: string;
  contaAzulYogaAudience: string;
}

export function resolveAudiences(
  domain: string,
  apiAudience?: string,
  mcpAudience?: string,
  contaAzulPublicHost?: string,
  contaAzulAudience?: string,
  contaAzulPublicPath?: string,
  contaAzulYogaPublicHost?: string,
  contaAzulYogaAudience?: string,
  contaAzulYogaPublicPath?: string,
): ResolvedAudiences {
  const resolvedContaAzulHost =
    contaAzulPublicHost ?? DEFAULT_CONTA_AZUL_PUBLIC_HOST;
  const resolvedContaAzulPath =
    contaAzulPublicPath ?? DEFAULT_CONTA_AZUL_PUBLIC_PATH;
  const resolvedContaAzulYogaHost =
    contaAzulYogaPublicHost ?? DEFAULT_CONTA_AZUL_YOGA_PUBLIC_HOST;
  const resolvedContaAzulYogaPath =
    contaAzulYogaPublicPath ?? DEFAULT_CONTA_AZUL_YOGA_PUBLIC_PATH;
  return {
    apiAudience: apiAudience ?? `https://dev.${domain}/api`,
    mcpAudience: mcpAudience ?? `https://dev.${domain}/mcp`,
    contaAzulAudience:
      contaAzulAudience ??
      buildContaAzulAudience(resolvedContaAzulHost, resolvedContaAzulPath),
    contaAzulYogaAudience:
      contaAzulYogaAudience ??
      buildContaAzulYogaAudience(
        resolvedContaAzulYogaHost,
        resolvedContaAzulYogaPath,
      ),
  };
}

export function issuerUrl(
  keycloakUrl: string,
  realmName: string = REALM_NAME,
): string {
  return `${keycloakUrl.replace(/\/$/, "")}/realms/${realmName}`;
}

export function googleBrokerRedirectUri(
  keycloakUrl: string,
  realmName: string = REALM_NAME,
  alias: string = GOOGLE_IDP_ALIAS,
): string {
  return `${keycloakUrl.replace(/\/$/, "")}/realms/${realmName}/broker/${alias}/endpoint`;
}

export function googleOauthRequiredRedirectUris(
  keycloakUrl: string,
  includeLocalhost: boolean,
  realmName: string = REALM_NAME,
  alias: string = GOOGLE_IDP_ALIAS,
): string[] {
  const uris = [googleBrokerRedirectUri(keycloakUrl, realmName, alias)];
  if (includeLocalhost) {
    uris.push(
      `http://localhost:8080/realms/${realmName}/broker/${alias}/endpoint`,
    );
  }
  return [...new Set(uris.filter(Boolean))];
}

export function loadKeycloakConfigFromPulumi(
  cfg: pulumi.Config = new pulumi.Config(),
): Omit<KeycloakConfigArgs, "provider"> & {
  keycloakAdminUsername: string;
  keycloakAdminPassword: pulumi.Output<string>;
} {
  const domain = cfg.get("domain") ?? "avcd.ai";
  const keycloakUrl = cfg.require("keycloakUrl");
  return {
    domain,
    odooPublicHost: cfg.get("odooPublicHost") ?? DEFAULT_ODOO_PUBLIC_HOST,
    aiPublicHost: cfg.get("aiPublicHost") ?? DEFAULT_AI_PUBLIC_HOST,
    frappePublicHost: cfg.get("frappePublicHost") ?? DEFAULT_FRAPPE_PUBLIC_HOST,
    contaAzulPublicHost:
      cfg.get("contaAzulPublicHost") ?? DEFAULT_CONTA_AZUL_PUBLIC_HOST,
    contaAzulPublicPath:
      cfg.get("contaAzulPublicPath") ?? DEFAULT_CONTA_AZUL_PUBLIC_PATH,
    contaAzulYogaPublicHost:
      cfg.get("contaAzulYogaPublicHost") ?? DEFAULT_CONTA_AZUL_YOGA_PUBLIC_HOST,
    contaAzulYogaPublicPath:
      cfg.get("contaAzulYogaPublicPath") ??
      DEFAULT_CONTA_AZUL_YOGA_PUBLIC_PATH,
    mcpPublicHost: cfg.get("mcpPublicHost"),
    keycloakUrl,
    apiAudience: cfg.get("apiAudience"),
    mcpAudience: cfg.get("mcpAudience"),
    enableGoogleIdentityProvider:
      cfg.getBoolean("enableGoogleIdentityProvider") ?? true,
    googleClientId:
      (cfg.getSecret("googleClientId") as string | undefined) ?? "",
    googleClientSecret:
      (cfg.getSecret("googleClientSecret") as string | undefined) ?? "",
    includeLocalhostGoogleRedirectUri:
      cfg.getBoolean("includeLocalhostGoogleRedirectUri") ?? true,
    odooClientSecret: cfg.getSecret("odooClientSecret"),
    aiClientSecret: cfg.getSecret("aiClientSecret"),
    frappeClientSecret: cfg.getSecret("frappeClientSecret"),
    contaAzulApiClientSecret: cfg.getSecret("contaAzulApiClientSecret"),
    keycloakAdminUsername: cfg.get("keycloakAdminUsername") ?? "admin",
    keycloakAdminPassword: cfg.requireSecret("keycloakAdminPassword"),
  };
}
