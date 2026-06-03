import * as pulumi from "@pulumi/pulumi";
import * as infisical from "pulumi-infisical";

const KEYCLOAK_FOLDER = "/keycloak";

export interface KeycloakSecretSpec {
  name: string;
  value: pulumi.Input<string>;
}

export interface KeycloakInfisicalSecretsArgs {
  provider: infisical.Provider;
  projectId: pulumi.Input<string>;
  envSlug: string;
  keycloakJdbcUrl: pulumi.Input<string>;
  keycloakDbUsername: string;
  keycloakDbPassword: pulumi.Input<string>;
  keycloakAdminPassword: pulumi.Input<string>;
  keycloakPostgresBootstrapUri: pulumi.Input<string>;
  keycloakHost: string;
  deployHost: pulumi.Input<string>;
  deployUser: string;
  infisicalApiUrl: string;
  keycloakImageTag: string;
}

export class KeycloakInfisicalSecrets extends pulumi.ComponentResource {
  constructor(
    name: string,
    args: KeycloakInfisicalSecretsArgs,
    opts?: pulumi.ComponentResourceOptions,
  ) {
    super("avcd:keycloak:KeycloakInfisicalSecrets", name, {}, opts);

    const folder = new infisical.SecretFolder(
      `${name}-folder`,
      {
        name: "keycloak",
        environmentSlug: args.envSlug,
        projectId: args.projectId,
        folderPath: "/",
      },
      { parent: this, provider: args.provider },
    );

    const secrets: KeycloakSecretSpec[] = [
      { name: "KC_DB_URL", value: args.keycloakJdbcUrl },
      { name: "KC_DB_USERNAME", value: args.keycloakDbUsername },
      { name: "KC_DB_PASSWORD", value: args.keycloakDbPassword },
      { name: "KEYCLOAK_ADMIN_PASSWORD", value: args.keycloakAdminPassword },
      { name: "KEYCLOAK_ADMIN", value: "admin" },
      { name: "KEYCLOAK_HOST", value: args.keycloakHost },
      { name: "DO_DEPLOY_HOST", value: args.deployHost },
      { name: "DO_DEPLOY_USER", value: args.deployUser },
      { name: "INFISICAL_API_URL", value: args.infisicalApiUrl },
      { name: "KEYCLOAK_IMAGE_TAG", value: args.keycloakImageTag },
      {
        name: "KEYCLOAK_POSTGRES_BOOTSTRAP_URI",
        value: args.keycloakPostgresBootstrapUri,
      },
    ];

    for (const spec of secrets) {
      new infisical.Secret(
        `${name}-secret-${spec.name.toLowerCase().replace(/_/g, "-")}`,
        {
          name: spec.name,
          // valueWo requires Terraform 1.11+ in the bridge; use value (pulumi.secret in stack).
          value: pulumi.secret(spec.value),
          envSlug: args.envSlug,
          workspaceId: args.projectId,
          folderPath: KEYCLOAK_FOLDER,
        },
        { parent: folder, provider: args.provider, dependsOn: [folder] },
      );
    }

    this.registerOutputs({ folderPath: KEYCLOAK_FOLDER, envSlug: args.envSlug });
  }
}
