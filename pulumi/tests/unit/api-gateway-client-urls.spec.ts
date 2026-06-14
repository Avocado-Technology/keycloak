import {
  buildApiGatewayAudience,
  buildApiGatewayGraphqlUrl,
  buildApiGatewayPublicUrl,
} from "../../src/keycloak-config/apiGatewayClientUrls";

describe("apiGatewayClientUrls", () => {
  it("builds public URL with path prefix", () => {
    expect(buildApiGatewayPublicUrl("dev.avocado.tech", "/api-gateway")).toBe(
      "https://dev.avocado.tech/api-gateway",
    );
  });

  it("builds JWT audience matching public URL", () => {
    expect(buildApiGatewayAudience("dev.avocado.tech")).toBe(
      "https://dev.avocado.tech/api-gateway",
    );
  });

  it("builds GraphQL endpoint URL", () => {
    expect(buildApiGatewayGraphqlUrl("dev.avocado.tech")).toBe(
      "https://dev.avocado.tech/api-gateway/",
    );
  });
});
