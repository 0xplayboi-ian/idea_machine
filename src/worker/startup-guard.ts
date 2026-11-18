import { workerDb } from "../db";

const CONFIG_TABLES = ["search_config", "judge_config", "anchor_ideas"] as const;

/**
 * Refuses to start if the worker's database role could modify config.
 * Config boundary, layer 3 of 4 (grants, ESLint, this guard, CI test).
 */
export async function assertWorkerIsReadOnlyOnConfig(): Promise<void> {
  const db = workerDb();
  for (const table of CONFIG_TABLES) {
    const rows = await db.$queryRawUnsafe<
      { upd: boolean; del: boolean; ins: boolean }[]
    >(
      `SELECT has_table_privilege(current_user, '${table}', 'UPDATE') AS upd,
              has_table_privilege(current_user, '${table}', 'DELETE') AS del,
              has_table_privilege(current_user, '${table}', 'INSERT') AS ins`,
    );
    const r = rows[0];
    if (r.upd || r.del || r.ins) {
      throw new Error(
        `STARTUP GUARD: worker role can modify ${table} (update=${r.upd}, delete=${r.del}, insert=${r.ins}). Refusing to start.`,
      );
    }
  }
}
