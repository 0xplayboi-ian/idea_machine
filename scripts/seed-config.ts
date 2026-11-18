import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const adapter = new PrismaPg({ connectionString: process.env.TUNER_DATABASE_URL });
const db = new PrismaClient({ adapter });

async function seed() {
  console.log("Seeding initial configuration...");

  await db.search_config.create({
    data: { cut_count: 5, search_buffer: 3, search_buffer_max: 12, notes: "Initial version 1" },
  });

  await db.judge_config.create({
    data: {
      dimension_weights: {
        vertical_specificity: 0.08,
        workflow_ownership: 0.15,
        pain_severity: 0.12,
        demand_budget: 0.12,
        saturation: 0.12,
        defensibility: 0.12,
        ai_necessity: 0.06,
        buyer_accessibility: 0.06,
        expansion_path: 0.05,
        regulatory_feasibility: 0.05,
        capital_efficiency: 0.05,
        tam_sanity: 0.02,
      },
      notes: "Initial version 1",
    },
  });

  console.log("Configuration seeded successfully.");
  await db.$disconnect();
}

seed().catch((e) => {
  console.error(e);
  process.exit(1);
});
