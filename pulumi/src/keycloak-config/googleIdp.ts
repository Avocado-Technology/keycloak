import * as pulumi from "@pulumi/pulumi";
import * as keycloak from "@pulumi/keycloak";
import { GOOGLE_IDP_ALIAS } from "./types";

export interface GoogleIdpResult {
  googleIdp?: keycloak.oidc.GoogleIdentityProvider;
}

export function shouldCreateGoogleIdp(
  enableGoogleIdentityProvider: boolean,
  googleClientId: string,
  googleClientSecret: string,
): boolean {
  return (
    enableGoogleIdentityProvider &&
    googleClientId !== "" &&
    googleClientSecret !== ""
  );
}

export function createGoogleIdp(
  name: string,
  realmId: pulumi.Input<string>,
  googleClientId: string,
  googleClientSecret: string,
  enableGoogleIdentityProvider: boolean,
  provider: keycloak.Provider,
  parent: pulumi.Resource,
): GoogleIdpResult {
  if (
    !shouldCreateGoogleIdp(
      enableGoogleIdentityProvider,
      googleClientId,
      googleClientSecret,
    )
  ) {
    return {};
  }

  const googleIdp = new keycloak.oidc.GoogleIdentityProvider(
    `${name}-idp-google`,
    {
      realm: realmId,
      alias: GOOGLE_IDP_ALIAS,
      displayName: "Google",
      clientId: googleClientId,
      clientSecret: googleClientSecret,
      enabled: true,
      trustEmail: true,
      syncMode: "IMPORT",
    },
    { parent, provider },
  );

  return { googleIdp };
}
