import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

// Three clients, three URLs, three roles. Never share a URL between them.
function client(envVar: string): PrismaClient {
  const url = process.env[envVar];
  if (!url) throw new Error(`${envVar} is not set`);
  return new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
}

let _worker: PrismaClient | undefined;

/** Worker runtime. Only the Trigger.dev worker should call this. */
export const workerDb = (): PrismaClient => (_worker ??= client("WORKER_DATABASE_URL"));

/** Reports server (SELECT only). */
export const reporterDb = (): PrismaClient => client("REPORTER_DATABASE_URL");

/** Tuner/label scripts (human credentials). Never import from src/worker. */
export const tunerDb = (): PrismaClient => client("TUNER_DATABASE_URL");
