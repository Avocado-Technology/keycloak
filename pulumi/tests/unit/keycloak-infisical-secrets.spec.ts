import { KeycloakInfisicalSecrets } from "../../src/components/KeycloakInfisicalSecrets";

const secretCreates: Array<Record<string, unknown>> = [];

jest.mock("pulumi-infisical", () => ({
  SecretFolder: jest.fn().mockImplementation(() => ({})),
  Secret: jest.fn().mockImplementation((_name, args) => {
    secretCreates.push(args);
    return {};
  }),
}));

describe("KeycloakInfisicalSecrets", () => {
  const mockProvider = {} as never;

  beforeEach(() => {
    secretCreates.length = 0;
  });

  const baseArgs = {
    provider: mockProvider,
    projectId: "proj-1",
    envSlug: "prod",
    keycloakJdbcUrl: "jdbc:postgresql://db:25060/keycloak?sslmode=require",
    keycloakDbUsername: "keycloak",
    keycloakDbPassword: "db-pass",
    keycloakAdminPassword: "admin-pass",
    keycloakPostgresBootstrapUri:
      "postgresql://doadmin:admin@db:25060/keycloak?sslmode=require",
    keycloakHost: "auth.avcd.ai",
    deployHost: "10.0.0.1",
    deployUser: "deploy",
    infisicalApiUrl: "https://secrets.avcd.ai/api",
    keycloakImageTag: "26.0",
  };

  it("GivenArgs_WhenCreating_ThenUsesValueNotValueWo", () => {
    new KeycloakInfisicalSecrets("kc-secrets", baseArgs);

    expect(secretCreates.length).toBeGreaterThan(0);
    for (const args of secretCreates) {
      expect(args).toHaveProperty("value");
      expect(args).not.toHaveProperty("valueWo");
      expect(args).not.toHaveProperty("valueWoVersion");
    }
  });

  it("GivenArgs_WhenCreating_ThenWritesRequiredSecrets", () => {
    new KeycloakInfisicalSecrets("kc-secrets", baseArgs);

    const names = secretCreates.map((a) => a.name);
    expect(names).toContain("KC_DB_URL");
    expect(names).toContain("KEYCLOAK_ADMIN_PASSWORD");
    expect(names).toContain("KEYCLOAK_POSTGRES_BOOTSTRAP_URI");
  });
});
