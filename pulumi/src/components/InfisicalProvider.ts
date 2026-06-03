import * as pulumi from "@pulumi/pulumi";
import * as infisical from "pulumi-infisical";

export const DEFAULT_INFISICAL_HOST = "https://secrets.avcd.ai";

export interface InfisicalProviderArgs {
  hostUrl?: string;
  serviceToken?: pulumi.Input<string>;
  clientId?: pulumi.Input<string>;
  clientSecret?: pulumi.Input<string>;
}

export function createInfisicalProvider(
  name: string,
  args: InfisicalProviderArgs,
  opts?: pulumi.ComponentResourceOptions,
): infisical.Provider {
  const host = args.hostUrl || DEFAULT_INFISICAL_HOST;

  if (args.clientId && args.clientSecret) {
    return new infisical.Provider(
      name,
      {
        host,
        auth: {
          universal: {
            clientId: args.clientId,
            clientSecret: args.clientSecret,
          },
        },
      },
      opts,
    );
  }

  if (args.serviceToken) {
    return new infisical.Provider(
      name,
      {
        host,
        serviceToken: args.serviceToken,
      },
      opts,
    );
  }

  throw new Error(
    "Infisical provider requires either serviceToken or clientId + clientSecret",
  );
}
