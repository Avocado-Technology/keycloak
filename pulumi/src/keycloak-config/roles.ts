import * as pulumi from "@pulumi/pulumi";
import * as keycloak from "@pulumi/keycloak";
import { AI_ACCESS_REALM_ROLE } from "./types";

export interface AvcdRolesResult {
  userRole: keycloak.Role;
  aiAccessRole: keycloak.Role;
  defaultRoles: keycloak.DefaultRoles;
}

export function createAvcdRoles(
  name: string,
  realmId: pulumi.Input<string>,
  provider: keycloak.Provider,
  parent: pulumi.Resource,
): AvcdRolesResult {
  const userRole = new keycloak.Role(
    `${name}-role-user`,
    {
      realmId,
      name: "user",
      description: "Default AVCD user role",
    },
    { parent, provider },
  );

  const aiAccessRole = new keycloak.Role(
    `${name}-role-ai-access`,
    {
      realmId,
      name: AI_ACCESS_REALM_ROLE,
      description:
        "Grants LibreChat (avcd-ai) access. Assign manually in Keycloak Admin — not a default realm role.",
    },
    { parent, provider },
  );

  const defaultRoles = new keycloak.DefaultRoles(
    `${name}-default-roles`,
    {
      realmId,
      defaultRoles: [userRole.name],
    },
    { parent, provider, dependsOn: [userRole] },
  );

  return { userRole, aiAccessRole, defaultRoles };
}
