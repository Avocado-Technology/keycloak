/** Pulumi infra stack in pulumi-infra (org/project/stack). */
export const INFRA_PULUMI_PROJECT = "avcd-infra";

export function buildInfraStackReference(org: string): string {
  const trimmedOrg = org.trim();
  if (!trimmedOrg) {
    throw new Error("buildInfraStackReference requires non-empty org");
  }
  return `${trimmedOrg}/${INFRA_PULUMI_PROJECT}/infra`;
}
