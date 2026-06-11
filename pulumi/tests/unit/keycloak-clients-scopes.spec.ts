import * as fs from "fs";
import * as path from "path";

const clientsSource = fs.readFileSync(
  path.join(__dirname, "../../src/keycloak-config/clients.ts"),
  "utf8",
);

describe("avcd-ai Keycloak default client scopes", () => {
  it("GivenAvcdAiClient_WhenDefaultScopesConfigured_ThenIncludesMcpAudienceAndOfflineAccess", () => {
    const blockStart = clientsSource.indexOf("client-ai-default-scopes");
    expect(blockStart).toBeGreaterThan(-1);

    const block = clientsSource.slice(blockStart, blockStart + 600);
    expect(block).toContain("scopes.mcpAudienceScope.name");
    expect(block).not.toContain('"openid"');
    expect(block).not.toContain('"offline_access"');
    expect(block).toContain(
      "dependsOn: [aiClient, scopes.subjectScope, scopes.mcpAudienceScope]",
    );
  });

  it("GivenAvcdAiClient_WhenOptionalScopesConfigured_ThenIncludesOfflineAccess", () => {
    const blockStart = clientsSource.indexOf("client-ai-optional-scopes");
    expect(blockStart).toBeGreaterThan(-1);

    const block = clientsSource.slice(blockStart, blockStart + 400);
    expect(block).toContain('"offline_access"');
  });

  it("GivenAvcdAiClient_WhenClientConfigured_ThenUseRefreshTokensEnabled", () => {
    const block = clientsSource.slice(
      clientsSource.indexOf("const aiClient = new keycloak.openid.Client"),
      clientsSource.indexOf("client-ai-default-scopes"),
    );
    expect(block).toContain("useRefreshTokens: true");
  });

  it("GivenAvcdMcpClient_WhenDefaultScopesConfigured_ThenIncludesMcpAudience", () => {
    const blockStart = clientsSource.indexOf("client-mcp-default-scopes");
    expect(blockStart).toBeGreaterThan(-1);

    const block = clientsSource.slice(blockStart, blockStart + 400);
    expect(block).toContain("scopes.mcpAudienceScope.name");
  });
});
