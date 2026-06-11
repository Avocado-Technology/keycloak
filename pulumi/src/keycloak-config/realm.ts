import * as pulumi from "@pulumi/pulumi";
import * as keycloak from "@pulumi/keycloak";
import { REALM_NAME } from "./types";

export interface AvcdRealmResult {
  realm: keycloak.Realm;
}

export function createAvcdRealm(
  name: string,
  provider: keycloak.Provider,
  parent: pulumi.Resource,
): AvcdRealmResult {
  const realm = new keycloak.Realm(
    `${name}-realm`,
    {
      realm: REALM_NAME,
      enabled: true,
      sslRequired: "external",
      registrationAllowed: false,
      loginWithEmailAllowed: true,
      duplicateEmailsAllowed: false,
      resetPasswordAllowed: false,
      editUsernameAllowed: false,
      securityDefenses: {
        bruteForceDetection: {
          maxLoginFailures: 30,
        },
      },
    },
    { parent, provider },
  );

  return { realm };
}
