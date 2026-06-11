import * as pulumi from "@pulumi/pulumi";

const stack = pulumi.getStack();

switch (stack) {
  case "secrets": {
    const secrets =
      require("./stacks/secrets") as typeof import("./stacks/secrets");
    exports.keycloakSecretsEnv = secrets.keycloakSecretsEnv;
    exports.keycloakSecretsFolder = secrets.keycloakSecretsFolder;
    break;
  }
  case "keycloak-config": {
    const config =
      require("./stacks/keycloak-config") as typeof import("./stacks/keycloak-config");
    for (const [key, value] of Object.entries(config)) {
      (exports as Record<string, unknown>)[key] = value;
    }
    break;
  }
  default:
    throw new Error(
      `Unknown stack: ${stack}. Valid: secrets | keycloak-config`,
    );
}
