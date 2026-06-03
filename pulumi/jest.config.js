/** @type {import('jest').Config} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  projects: [
    {
      displayName: "unit",
      preset: "ts-jest",
      testEnvironment: "node",
      testMatch: ["<rootDir>/tests/unit/**/*.spec.ts"],
      moduleFileExtensions: ["ts", "js", "json"],
    },
  ],
};
