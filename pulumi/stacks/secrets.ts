import * as pulumi from "@pulumi/pulumi";
import { createInfisicalProvider } from "../src/components/InfisicalProvider";
import { KeycloakInfisicalSecrets } from "../src/components/KeycloakInfisicalSecrets";
import { buildInfraStackReference } from "../src/stackReference";
import {
  getInfisicalClientId,
  getInfisicalClientSecret,
} from "../src/infisicalAuth";

const cfg = new pulumi.Config();

const serviceToken = cfg.getSecret("infisicalServiceToken");
const clientId = getInfisicalClientId(cfg);
const clientSecret = getInfisicalClientSecret(cfg);

const infisicalProvider = createInfisicalProvider("infisical", {
  hostUrl: cfg.get("infisicalHostUrl") || "https://secrets.avcd.ai",
  serviceToken,
  clientId,
  clientSecret,
});

const org = cfg.get("pulumiOrg") || pulumi.getOrganization() || "organization";
const infraStack = new pulumi.StackReference(buildInfraStackReference(org));

const keycloakJdbcUrl = infraStack.requireOutput("keycloakJdbcUrl");
const keycloakDbPassword = infraStack.requireOutput("keycloakDbPassword");
const keycloakAdminPassword = infraStack.requireOutput("keycloakAdminPassword");
const keycloakPostgresBootstrapUri = infraStack.requireOutput(
  "keycloakPostgresBootstrapUri",
);
const infraDropletIp = infraStack.requireOutput("infraDropletIp");

const projectId =
  cfg.get("infisicalInfraProjectId") ||
  cfg.require("infisicalInfraProjectId");

const domain = cfg.get("domain") || "avcd.ai";
const keycloakHost = cfg.get("keycloakHost") || `auth.${domain}`;
const envSlug = cfg.get("secretsEnvSlug") || "prod";
const deployUser = cfg.get("deployUser") || "deploy";
const keycloakImageTag = cfg.get("keycloakImageTag") || "26.0";
const infisicalApiUrl =
  cfg.get("infisicalApiUrl") || "https://secrets.avcd.ai/api";

new KeycloakInfisicalSecrets("avcd-keycloak-secrets", {
  provider: infisicalProvider,
  projectId,
  envSlug,
  keycloakJdbcUrl,
  keycloakDbUsername: "keycloak",
  keycloakDbPassword,
  keycloakAdminPassword,
  keycloakPostgresBootstrapUri,
  keycloakHost,
  deployHost: infraDropletIp,
  deployUser,
  infisicalApiUrl,
  keycloakImageTag,
});

export const keycloakSecretsEnv = envSlug;
export const keycloakSecretsFolder = "/keycloak";
