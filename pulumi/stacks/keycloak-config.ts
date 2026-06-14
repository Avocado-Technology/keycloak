import * as keycloak from "@pulumi/keycloak";
import { KeycloakConfig } from "../src/keycloak-config/KeycloakConfig";
import { loadKeycloakConfigFromPulumi } from "../src/keycloak-config/types";

const cfg = loadKeycloakConfigFromPulumi();

const keycloakProvider = new keycloak.Provider("keycloak", {
  url: cfg.keycloakUrl,
  realm: "master",
  clientId: "admin-cli",
  username: cfg.keycloakAdminUsername,
  password: cfg.keycloakAdminPassword,
});

const keycloakConfig = new KeycloakConfig("avcd", {
  provider: keycloakProvider,
  domain: cfg.domain,
  keycloakUrl: cfg.keycloakUrl,
  odooPublicHost: cfg.odooPublicHost,
  aiPublicHost: cfg.aiPublicHost,
  frappePublicHost: cfg.frappePublicHost,
  contaAzulPublicHost: cfg.contaAzulPublicHost,
  contaAzulYogaPublicHost: cfg.contaAzulYogaPublicHost,
  contaAzulYogaPublicPath: cfg.contaAzulYogaPublicPath,
  apiAudience: cfg.apiAudience,
  mcpAudience: cfg.mcpAudience,
  enableGoogleIdentityProvider: cfg.enableGoogleIdentityProvider,
  googleClientId: cfg.googleClientId,
  googleClientSecret: cfg.googleClientSecret,
  includeLocalhostGoogleRedirectUri: cfg.includeLocalhostGoogleRedirectUri,
  odooClientSecret: cfg.odooClientSecret,
  aiClientSecret: cfg.aiClientSecret,
  frappeClientSecret: cfg.frappeClientSecret,
  contaAzulApiClientSecret: cfg.contaAzulApiClientSecret,
});

export const issuerUrl = keycloakConfig.issuerUrlOut;
export const realmName = keycloakConfig.realmName;
export const webClientId = keycloakConfig.webClientId;
export const webClientSecret = keycloakConfig.webClientSecret;
export const mcpClientId = keycloakConfig.mcpClientId;
export const odooClientId = keycloakConfig.odooClientId;
export const odooClientSecret = keycloakConfig.odooClientSecret;
export const aiClientId = keycloakConfig.aiClientId;
export const aiClientSecret = keycloakConfig.aiClientSecret;
export const frappeClientId = keycloakConfig.frappeClientId;
export const frappeClientSecret = keycloakConfig.frappeClientSecret;
export const contaAzulApiClientId = keycloakConfig.contaAzulApiClientId;
export const contaAzulApiClientSecret = keycloakConfig.contaAzulApiClientSecret;
export const googleOauthRequiredRedirectUris =
  keycloakConfig.googleOauthRequiredRedirectUrisOut;
export const webOidcAuthorizationScope =
  keycloakConfig.webOidcAuthorizationScope;
