import * as pulumi from "@pulumi/pulumi";

/** Prefer CI env vars over encrypted stack config. */
export function getInfisicalClientId(
  cfg: pulumi.Config,
): pulumi.Input<string> | undefined {
  const fromEnv = process.env.INFISICAL_CLIENT_ID?.trim();
  if (fromEnv) {
    return fromEnv;
  }
  return (
    cfg.getSecret("infisicalClientId") ??
    cfg.getSecret("infisicalUniversalAuthClientId")
  );
}

export function getInfisicalClientSecret(
  cfg: pulumi.Config,
): pulumi.Input<string> | undefined {
  const fromEnv = process.env.INFISICAL_CLIENT_SECRET?.trim();
  if (fromEnv) {
    return fromEnv;
  }
  return (
    cfg.getSecret("infisicalClientSecret") ??
    cfg.getSecret("infisicalUniversalAuthClientSecret")
  );
}
