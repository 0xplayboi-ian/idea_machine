import { defineConfig } from "@trigger.dev/sdk";
import { prismaExtension } from "@trigger.dev/build/extensions/prisma";

export default defineConfig({
  project: "proj_wlwtbrqqpcsdekzifmxq",
  runtime: "node",
  logLevel: "info",
  maxDuration: 3600,
  retries: { enabled: true, maxAttempts: 3 },
  build: {
    extensions: [
      prismaExtension({
        mode: "legacy",
        schema: "prisma/schema.prisma",
        migrate: true,
        typedSql: true,
        directUrlEnvVarName: "WORKER_DATABASE_URL_UNPOOLED",
      }),
    ],
  },
});
