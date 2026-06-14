import * as pulumi from "@pulumi/pulumi";
import * as keycloak from "@pulumi/keycloak";
import type { AvcdScopesResult } from "./scopes";
import {
  buildAiPostLogoutRedirectUris,
  buildAiRedirectUris,
  buildAiWebOrigins,
  DEFAULT_AI_PUBLIC_HOST,
} from "./aiClientUrls";
import {
  buildFrappeRedirectUris,
  buildFrappeWebOrigins,
  DEFAULT_FRAPPE_PUBLIC_HOST,
} from "./frappeClientUrls";
import { CONTA_AZUL_API_CLIENT_ID } from "./contaAzulClientUrls";
import {
  buildOdooRedirectUris,
  buildOdooWebOrigins,
  DEFAULT_ODOO_PUBLIC_HOST,
} from "./odooClientUrls";
import {
  buildMcpRedirectUris,
  buildMcpWebOrigins,
  DEFAULT_MCP_PUBLIC_HOST,
} from "./mcpClientUrls";
import {
  buildWebPostLogoutRedirectUris,
  buildWebRedirectUris,
  buildWebWebOrigins,
  WEB_CLIENT_ID,
} from "./webClientUrls";

export const ODOO_CLIENT_ID = "avcd-odoo";
export const AI_CLIENT_ID = "avcd-ai";
export const FRAPPE_CLIENT_ID = "avcd-frappe";
export { CONTA_AZUL_API_CLIENT_ID };

export interface AvcdClientsResult {
  webClient: keycloak.openid.Client;
  mcpClient: keycloak.openid.Client;
  odooClient: keycloak.openid.Client;
  aiClient: keycloak.openid.Client;
  frappeClient: keycloak.openid.Client;
  contaAzulApiClient: keycloak.openid.Client;
}

export function createAvcdClients(
  name: string,
  realmId: pulumi.Input<string>,
  domain: string,
  odooPublicHost: string,
  aiPublicHost: string,
  frappePublicHost: string,
  mcpPublicHost: string,
  scopes: AvcdScopesResult,
  aiAccessRoleId: pulumi.Input<string>,
  odooClientSecret: pulumi.Input<string>,
  aiClientSecret: pulumi.Input<string>,
  frappeClientSecret: pulumi.Input<string>,
  contaAzulApiClientSecret: pulumi.Input<string>,
  provider: keycloak.Provider,
  parent: pulumi.Resource,
): AvcdClientsResult {
  const resolvedOdooPublicHost = odooPublicHost || DEFAULT_ODOO_PUBLIC_HOST;
  const resolvedAiPublicHost = aiPublicHost || DEFAULT_AI_PUBLIC_HOST;
  const resolvedFrappePublicHost =
    frappePublicHost || DEFAULT_FRAPPE_PUBLIC_HOST;
  const resolvedMcpPublicHost = mcpPublicHost || DEFAULT_MCP_PUBLIC_HOST;
  const webClient = new keycloak.openid.Client(
    `${name}-client-web`,
    {
      realmId,
      clientId: WEB_CLIENT_ID,
      name: "AVCD Web Portal",
      accessType: "CONFIDENTIAL",
      standardFlowEnabled: true,
      directAccessGrantsEnabled: false,
      serviceAccountsEnabled: false,
      fullScopeAllowed: true,
      useRefreshTokens: true,
      validRedirectUris: buildWebRedirectUris(domain),
      validPostLogoutRedirectUris: buildWebPostLogoutRedirectUris(domain),
      webOrigins: buildWebWebOrigins(domain),
    },
    { parent, provider },
  );

  // Realm defaults (profile, email, roles, web-origins) are implicit — listing them causes drift.
  new keycloak.openid.ClientDefaultScopes(
    `${name}-client-web-default-scopes`,
    {
      realmId,
      clientId: webClient.id,
      defaultScopes: [
        scopes.subjectScope.name,
        scopes.apiAudienceScope.name,
        "profile",
        "email",
      ],
    },
    {
      parent,
      provider,
      dependsOn: [webClient, scopes.subjectScope, scopes.apiAudienceScope],
    },
  );

  new keycloak.openid.ClientOptionalScopes(
    `${name}-client-web-optional-scopes`,
    {
      realmId,
      clientId: webClient.id,
      optionalScopes: [
        scopes.apiGatewayAudienceScope.name,
        scopes.contaAzulYogaAudienceScope.name,
      ],
    },
    {
      parent,
      provider,
      dependsOn: [
        webClient,
        scopes.apiGatewayAudienceScope,
        scopes.contaAzulYogaAudienceScope,
      ],
    },
  );

  const mcpClient = new keycloak.openid.Client(
    `${name}-client-mcp`,
    {
      realmId,
      clientId: "avcd-mcp",
      name: "AVCD MCP Server",
      accessType: "PUBLIC",
      standardFlowEnabled: true,
      directAccessGrantsEnabled: false,
      serviceAccountsEnabled: false,
      fullScopeAllowed: true,
      validRedirectUris: buildMcpRedirectUris(resolvedMcpPublicHost, domain),
      webOrigins: buildMcpWebOrigins(resolvedMcpPublicHost, domain),
      pkceCodeChallengeMethod: "S256",
    },
    { parent, provider },
  );

  new keycloak.openid.ClientDefaultScopes(
    `${name}-client-mcp-default-scopes`,
    {
      realmId,
      clientId: mcpClient.id,
      defaultScopes: [scopes.subjectScope.name, scopes.mcpAudienceScope.name],
    },
    {
      parent,
      provider,
      dependsOn: [mcpClient, scopes.subjectScope, scopes.mcpAudienceScope],
    },
  );

  const odooClient = new keycloak.openid.Client(
    `${name}-client-odoo`,
    {
      realmId,
      clientId: ODOO_CLIENT_ID,
      name: "AVCD Odoo ERP",
      description:
        "Confidential OIDC client for Odoo SSO (Authorization Code Flow).",
      accessType: "CONFIDENTIAL",
      clientSecret: odooClientSecret,
      standardFlowEnabled: true,
      directAccessGrantsEnabled: false,
      serviceAccountsEnabled: false,
      fullScopeAllowed: false,
      validRedirectUris: buildOdooRedirectUris(resolvedOdooPublicHost),
      webOrigins: buildOdooWebOrigins(resolvedOdooPublicHost),
    },
    { parent, provider },
  );

  new keycloak.openid.ClientDefaultScopes(
    `${name}-client-odoo-default-scopes`,
    {
      realmId,
      clientId: odooClient.id,
      defaultScopes: ["openid", scopes.subjectScope.name, "email", "profile"],
    },
    {
      parent,
      provider,
      dependsOn: [odooClient, scopes.subjectScope],
    },
  );

  const aiClient = new keycloak.openid.Client(
    `${name}-client-ai`,
    {
      realmId,
      clientId: AI_CLIENT_ID,
      name: "AVCD AI Chat",
      description:
        "Confidential OIDC client for LibreChat SSO (Authorization Code Flow).",
      accessType: "CONFIDENTIAL",
      clientSecret: aiClientSecret,
      standardFlowEnabled: true,
      directAccessGrantsEnabled: false,
      serviceAccountsEnabled: false,
      fullScopeAllowed: false,
      useRefreshTokens: true,
      validRedirectUris: buildAiRedirectUris(resolvedAiPublicHost),
      validPostLogoutRedirectUris:
        buildAiPostLogoutRedirectUris(resolvedAiPublicHost),
      webOrigins: buildAiWebOrigins(resolvedAiPublicHost),
    },
    { parent, provider },
  );

  new keycloak.openid.ClientDefaultScopes(
    `${name}-client-ai-default-scopes`,
    {
      realmId,
      clientId: aiClient.id,
      // roles: required so access tokens include realm_access.roles (LibreChat OPENID_REQUIRED_ROLE gate)
      // openid/profile/email/roles are realm default client scopes — do not list openid (Keycloak API rejects it).
      defaultScopes: [
        scopes.subjectScope.name,
        "email",
        "profile",
        "roles",
        scopes.mcpAudienceScope.name,
      ],
    },
    {
      parent,
      provider,
      dependsOn: [aiClient, scopes.subjectScope, scopes.mcpAudienceScope],
    },
  );

  // offline_access must be optional (not default) — LibreChat requests it via OPENID_SCOPE.
  new keycloak.openid.ClientOptionalScopes(
    `${name}-client-ai-optional-scopes`,
    {
      realmId,
      clientId: aiClient.id,
      optionalScopes: [
        "address",
        "phone",
        "offline_access",
        "microprofile-jwt",
      ],
    },
    {
      parent,
      provider,
      dependsOn: [aiClient],
    },
  );

  // fullScopeAllowed=false limits token roles to explicitly assigned scope mappings (Keycloak 26).
  new keycloak.GenericRoleMapper(
    `${name}-client-ai-access-scope-map`,
    {
      realmId,
      clientId: aiClient.id,
      roleId: aiAccessRoleId,
    },
    {
      parent,
      provider,
      dependsOn: [aiClient],
    },
  );

  const frappeClient = new keycloak.openid.Client(
    `${name}-client-frappe`,
    {
      realmId,
      clientId: FRAPPE_CLIENT_ID,
      name: "AVCD Frappe ERP",
      description:
        "Confidential OIDC client for Frappe/ERPNext SSO (Authorization Code Flow).",
      accessType: "CONFIDENTIAL",
      clientSecret: frappeClientSecret,
      standardFlowEnabled: true,
      directAccessGrantsEnabled: false,
      serviceAccountsEnabled: false,
      fullScopeAllowed: false,
      validRedirectUris: buildFrappeRedirectUris(resolvedFrappePublicHost),
      webOrigins: buildFrappeWebOrigins(resolvedFrappePublicHost),
    },
    { parent, provider },
  );

  new keycloak.openid.ClientDefaultScopes(
    `${name}-client-frappe-default-scopes`,
    {
      realmId,
      clientId: frappeClient.id,
      defaultScopes: ["openid", scopes.subjectScope.name, "email", "profile"],
    },
    {
      parent,
      provider,
      dependsOn: [frappeClient, scopes.subjectScope],
    },
  );

  const contaAzulApiClient = new keycloak.openid.Client(
    `${name}-client-conta-azul-api`,
    {
      realmId,
      clientId: CONTA_AZUL_API_CLIENT_ID,
      name: "AVCD Conta Azul API",
      description:
        "Confidential M2M client for Conta Azul Service (client_credentials grant).",
      accessType: "CONFIDENTIAL",
      clientSecret: contaAzulApiClientSecret,
      standardFlowEnabled: false,
      directAccessGrantsEnabled: false,
      serviceAccountsEnabled: true,
      fullScopeAllowed: false,
    },
    { parent, provider },
  );

  new keycloak.openid.ClientDefaultScopes(
    `${name}-client-conta-azul-api-default-scopes`,
    {
      realmId,
      clientId: contaAzulApiClient.id,
      defaultScopes: [
        scopes.contaAzulAudienceScope.name,
        scopes.contaAzulYogaAudienceScope.name,
        scopes.apiGatewayAudienceScope.name,
      ],
    },
    {
      parent,
      provider,
      dependsOn: [
        contaAzulApiClient,
        scopes.contaAzulAudienceScope,
        scopes.contaAzulYogaAudienceScope,
        scopes.apiGatewayAudienceScope,
      ],
    },
  );

  return {
    webClient,
    mcpClient,
    odooClient,
    aiClient,
    frappeClient,
    contaAzulApiClient,
  };
}
