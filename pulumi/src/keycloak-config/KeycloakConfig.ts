import * as pulumi from "@pulumi/pulumi";
import * as keycloak from "@pulumi/keycloak";
import * as random from "@pulumi/random";
import { createAvcdClients } from "./clients";
import { createGoogleIdp } from "./googleIdp";
import { createAvcdRealm } from "./realm";
import { createAvcdRoles } from "./roles";
import { createAvcdScopes } from "./scopes";
import {
  googleOauthRequiredRedirectUris,
  issuerUrl,
  REALM_NAME,
  resolveAudiences,
  WEB_OIDC_AUTHORIZATION_SCOPE,
  type KeycloakConfigArgs,
} from "./types";

export class KeycloakConfig extends pulumi.ComponentResource {
  public readonly realm: keycloak.Realm;
  public readonly webClient: keycloak.openid.Client;
  public readonly mcpClient: keycloak.openid.Client;
  public readonly odooClient: keycloak.openid.Client;
  public readonly aiClient: keycloak.openid.Client;
  public readonly frappeClient: keycloak.openid.Client;
  public readonly contaAzulApiClient: keycloak.openid.Client;
  public readonly googleIdp?: keycloak.oidc.GoogleIdentityProvider;

  public readonly issuerUrlOut: pulumi.Output<string>;
  public readonly realmName: pulumi.Output<string>;
  public readonly webClientId: pulumi.Output<string>;
  public readonly webClientSecret: pulumi.Output<string | undefined>;
  public readonly mcpClientId: pulumi.Output<string>;
  public readonly odooClientId: pulumi.Output<string>;
  public readonly odooClientSecret: pulumi.Output<string | undefined>;
  public readonly aiClientId: pulumi.Output<string>;
  public readonly aiClientSecret: pulumi.Output<string | undefined>;
  public readonly frappeClientId: pulumi.Output<string>;
  public readonly frappeClientSecret: pulumi.Output<string | undefined>;
  public readonly contaAzulApiClientId: pulumi.Output<string>;
  public readonly contaAzulApiClientSecret: pulumi.Output<string | undefined>;
  public readonly googleOauthRequiredRedirectUrisOut: pulumi.Output<string[]>;
  public readonly webOidcAuthorizationScope: string;

  constructor(
    name: string,
    args: KeycloakConfigArgs,
    opts?: pulumi.ComponentResourceOptions,
  ) {
    super("avcd:infra:KeycloakConfig", name, {}, opts);

    const audiences = resolveAudiences(
      args.domain,
      args.apiAudience,
      args.mcpAudience,
      args.contaAzulPublicHost,
      undefined,
      args.contaAzulPublicPath,
    );

    const { realm } = createAvcdRealm(name, args.provider, this);
    const { aiAccessRole } = createAvcdRoles(
      name,
      realm.id,
      args.provider,
      this,
    );
    const scopes = createAvcdScopes(
      name,
      realm.id,
      audiences,
      args.provider,
      this,
    );

    const generatedOdooSecret = args.odooClientSecret
      ? undefined
      : new random.RandomPassword(`${name}-odoo-client-secret`, {
          length: 32,
          special: true,
        });
    const odooClientSecret =
      args.odooClientSecret ?? generatedOdooSecret!.result;

    const generatedAiSecret = args.aiClientSecret
      ? undefined
      : new random.RandomPassword(`${name}-ai-client-secret`, {
          length: 32,
          special: true,
        });
    const aiClientSecret = args.aiClientSecret ?? generatedAiSecret!.result;

    const generatedFrappeSecret = args.frappeClientSecret
      ? undefined
      : new random.RandomPassword(`${name}-frappe-client-secret`, {
          length: 32,
          special: true,
        });
    const frappeClientSecret =
      args.frappeClientSecret ?? generatedFrappeSecret!.result;

    const generatedContaAzulApiSecret = args.contaAzulApiClientSecret
      ? undefined
      : new random.RandomPassword(`${name}-conta-azul-api-client-secret`, {
          length: 32,
          special: true,
        });
    const contaAzulApiClientSecret =
      args.contaAzulApiClientSecret ?? generatedContaAzulApiSecret!.result;

    const {
      webClient,
      mcpClient,
      odooClient,
      aiClient,
      frappeClient,
      contaAzulApiClient,
    } = createAvcdClients(
      name,
      realm.id,
      args.domain,
      args.odooPublicHost ?? "",
      args.aiPublicHost ?? "",
      args.frappePublicHost ?? "",
      scopes,
      aiAccessRole.id,
      odooClientSecret,
      aiClientSecret,
      frappeClientSecret,
      contaAzulApiClientSecret,
      args.provider,
      this,
    );

    const { googleIdp } = createGoogleIdp(
      name,
      realm.id,
      args.googleClientId ?? "",
      args.googleClientSecret ?? "",
      args.enableGoogleIdentityProvider ?? true,
      args.provider,
      this,
    );

    this.realm = realm;
    this.webClient = webClient;
    this.mcpClient = mcpClient;
    this.odooClient = odooClient;
    this.aiClient = aiClient;
    this.frappeClient = frappeClient;
    this.contaAzulApiClient = contaAzulApiClient;
    this.googleIdp = googleIdp;

    this.issuerUrlOut = pulumi.output(issuerUrl(args.keycloakUrl, REALM_NAME));
    this.realmName = pulumi.output(REALM_NAME);
    this.webClientId = webClient.clientId;
    this.webClientSecret = webClient.clientSecret;
    this.mcpClientId = mcpClient.clientId;
    this.odooClientId = odooClient.clientId;
    this.odooClientSecret = odooClient.clientSecret;
    this.aiClientId = aiClient.clientId;
    this.aiClientSecret = aiClient.clientSecret;
    this.frappeClientId = frappeClient.clientId;
    this.frappeClientSecret = frappeClient.clientSecret;
    this.contaAzulApiClientId = contaAzulApiClient.clientId;
    this.contaAzulApiClientSecret = contaAzulApiClient.clientSecret;
    this.webOidcAuthorizationScope = WEB_OIDC_AUTHORIZATION_SCOPE;
    this.googleOauthRequiredRedirectUrisOut = pulumi.output(
      googleOauthRequiredRedirectUris(
        args.keycloakUrl,
        args.includeLocalhostGoogleRedirectUri ?? true,
      ),
    );

    this.registerOutputs({
      issuerUrl: this.issuerUrlOut,
      realmName: this.realmName,
      webClientId: this.webClientId,
      mcpClientId: this.mcpClientId,
      googleOauthRequiredRedirectUris: this.googleOauthRequiredRedirectUrisOut,
      webOidcAuthorizationScope: this.webOidcAuthorizationScope,
    });
  }
}
