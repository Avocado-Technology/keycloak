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
  default:
    throw new Error(`Unknown stack: ${stack}. Valid: secrets`);
}
