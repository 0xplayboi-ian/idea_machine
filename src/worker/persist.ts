import { workerDb } from "../db";
import { Idea } from "./types";

export async function persist(
  cuts: any[],
  fillers: any[],
  iteration: number
): Promise<void> {
  await workerDb().$transaction(async (tx) => {
    // 1. Mark cuts
    // 2. Mark fillers
    // 3. Invariant check
    const count = await tx.ideas.count({ where: { status: "active" } });
    if (count !== 15) {
      throw new Error(`Invariant violation: expected 15 ideas, found ${count}`);
    }
  });
}
