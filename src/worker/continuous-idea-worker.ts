import { logger, task, wait } from "@trigger.dev/sdk";
import { workerDb } from "../db";
import { assertWorkerIsReadOnlyOnConfig } from "./startup-guard";

type Configs = { searchVersion: number; judgeVersion: number };

// Step 1 of the loop: re-read active configs EVERY iteration. Never cache.
async function loadConfigs(): Promise<Configs> {
  const db = workerDb();
  const s = await db.search_config.findFirst({ where: { is_active: true }, orderBy: { version: "desc" } });
  const j = await db.judge_config.findFirst({ where: { is_active: true }, orderBy: { version: "desc" } });
  if (!s || !j) throw new Error("No active config. Run scripts/seed-config.ts");
  return { searchVersion: s.version, judgeVersion: j.version };
}

// STUB: replaced by the real iteration in Phase 3.
async function runOneIteration(iteration: number): Promise<void> {
  const cfg = await loadConfigs();
  logger.info("iteration (stub)", { iteration, ...cfg });
  await workerDb().cycle_metrics.create({
    data: { iteration, active_count_after: 0, shortfall: true },
  });
}

export const continuousIdeaWorker = task({
  id: "continuous-idea-worker",
  concurrency: { total: 1 },
  retry: { maxAttempts: 5, factor: 2, minTimeoutInMs: 5_000 },
  maxDuration: 6 * 3600,
  run: async (payload: { maxIterations?: number } = {}) => {
    await assertWorkerIsReadOnlyOnConfig();
    let iteration = 0;
    // maxIterations exists only so Phase 2 can be tested with 5 loops.
    // Omit it in production for the forever-loop.
    while (payload.maxIterations === undefined || iteration < payload.maxIterations) {
      try {
        await runOneIteration(iteration);
      } catch (err) {
        logger.error("iteration failed", { iteration, err: String(err) });
        await wait.for({ seconds: 30 }); // error-only backoff
      }
      iteration++;
    }
    return { iterations: iteration };
  },
});
