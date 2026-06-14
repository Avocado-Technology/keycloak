import * as pulumi from "@pulumi/pulumi";
import * as keycloak from "@pulumi/keycloak";
import type { ResolvedAudiences } from "./types";

export interface AvcdScopesResult {
  apiAudienceScope: keycloak.openid.ClientScope;
  mcpAudienceScope: keycloak.openid.ClientScope;
  contaAzulAudienceScope: keycloak.openid.ClientScope;
  contaAzulYogaAudienceScope: keycloak.openid.ClientScope;
  /** Custom scope for `sub` claim — must not be named `openid` (breaks OIDC scope validation). */
  subjectScope: keycloak.openid.ClientScope;
}

export function createAvcdScopes(
  name: string,
  realmId: pulumi.Input<string>,
  audiences: ResolvedAudiences,
  provider: keycloak.Provider,
  parent: pulumi.Resource,
): AvcdScopesResult {
  const apiAudienceScope = new keycloak.openid.ClientScope(
    `${name}-scope-api-audience`,
    {
      realmId,
      name: "avcd-api-audience",
      description: "Adds GraphQL API audience claim to access tokens",
      includeInTokenScope: true,
    },
    { parent, provider },
  );

  new keycloak.openid.AudienceProtocolMapper(
    `${name}-mapper-api-audience`,
    {
      realmId,
      clientScopeId: apiAudienceScope.id,
      name: "avcd-api-audience-mapper",
      includedCustomAudience: audiences.apiAudience,
      addToIdToken: true,
      addToAccessToken: true,
    },
    { parent, provider, dependsOn: [apiAudienceScope] },
  );

  const mcpAudienceScope = new keycloak.openid.ClientScope(
    `${name}-scope-mcp-audience`,
    {
      realmId,
      name: "avcd-mcp-audience",
      description: "Adds MCP API audience claim to access tokens",
      includeInTokenScope: true,
    },
    { parent, provider },
  );

  new keycloak.openid.AudienceProtocolMapper(
    `${name}-mapper-mcp-audience`,
    {
      realmId,
      clientScopeId: mcpAudienceScope.id,
      name: "avcd-mcp-audience-mapper",
      includedCustomAudience: audiences.mcpAudience,
      addToIdToken: true,
      addToAccessToken: true,
    },
    { parent, provider, dependsOn: [mcpAudienceScope] },
  );

  const contaAzulAudienceScope = new keycloak.openid.ClientScope(
    `${name}-scope-conta-azul-audience`,
    {
      realmId,
      name: "avcd-conta-azul-audience",
      description:
        "Adds Conta Azul Service API audience claim to access tokens",
      includeInTokenScope: true,
    },
    { parent, provider },
  );

  new keycloak.openid.AudienceProtocolMapper(
    `${name}-mapper-conta-azul-audience`,
    {
      realmId,
      clientScopeId: contaAzulAudienceScope.id,
      name: "avcd-conta-azul-audience-mapper",
      includedCustomAudience: audiences.contaAzulAudience,
      addToIdToken: false,
      addToAccessToken: true,
    },
    { parent, provider, dependsOn: [contaAzulAudienceScope] },
  );

  const contaAzulYogaAudienceScope = new keycloak.openid.ClientScope(
    `${name}-scope-conta-azul-yoga-audience`,
    {
      realmId,
      name: "avcd-conta-azul-yoga-audience",
      description:
        "Adds Conta Azul Yoga Subgraph API audience claim to access tokens",
      includeInTokenScope: true,
    },
    { parent, provider },
  );

  new keycloak.openid.AudienceProtocolMapper(
    `${name}-mapper-conta-azul-yoga-audience`,
    {
      realmId,
      clientScopeId: contaAzulYogaAudienceScope.id,
      name: "avcd-conta-azul-yoga-audience-mapper",
      includedCustomAudience: audiences.contaAzulYogaAudience,
      addToIdToken: false,
      addToAccessToken: true,
    },
    { parent, provider, dependsOn: [contaAzulYogaAudienceScope] },
  );

  const subjectScope = new keycloak.openid.ClientScope(
    `${name}-scope-subject`,
    {
      realmId,
      name: "avcd-subject",
      description: "Subject (sub) claim for AVCD tokens",
      includeInTokenScope: true,
    },
    { parent, provider },
  );

  new keycloak.openid.SubProtocolMapper(
    `${name}-mapper-subject-sub`,
    {
      realmId,
      clientScopeId: subjectScope.id,
      name: "sub",
      addToAccessToken: true,
      addToTokenIntrospection: true,
    },
    { parent, provider, dependsOn: [subjectScope] },
  );

  return {
    apiAudienceScope,
    mcpAudienceScope,
    contaAzulAudienceScope,
    contaAzulYogaAudienceScope,
    subjectScope,
  };
}
