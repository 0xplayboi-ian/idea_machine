CREATE TABLE IF NOT EXISTS search_config (
  version SERIAL PRIMARY KEY,
  is_active BOOLEAN NOT NULL DEFAULT true,
  cut_count INT NOT NULL DEFAULT 5,
  search_buffer INT NOT NULL DEFAULT 3,
  search_buffer_max INT NOT NULL DEFAULT 12,
  dedupe_threshold DOUBLE PRECISION NOT NULL DEFAULT 0.88,
  dedupe_jaccard DOUBLE PRECISION NOT NULL DEFAULT 0.85,
  dedupe_elim_window INT NOT NULL DEFAULT 200,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  notes TEXT
);

CREATE TABLE IF NOT EXISTS judge_config (
  version SERIAL PRIMARY KEY,
  is_active BOOLEAN NOT NULL DEFAULT true,
  dimension_weights JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  notes TEXT
);

CREATE TABLE IF NOT EXISTS ideas (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  status TEXT NOT NULL,
  composite DOUBLE PRECISION NOT NULL DEFAULT 0,
  last_composite DOUBLE PRECISION NOT NULL DEFAULT 0,
  times_reinstated INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cycle_metrics (
  id SERIAL PRIMARY KEY,
  iteration INT NOT NULL,
  active_count_after INT NOT NULL,
  shortfall BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Roles (run the rest after the tables exist)
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'worker') THEN CREATE ROLE worker NOINHERIT; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO worker, tuner;
GRANT SELECT ON search_config, judge_config TO worker;
GRANT SELECT, INSERT, UPDATE ON ideas, cycle_metrics TO worker;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO worker, tuner;
GRANT SELECT, INSERT, UPDATE ON search_config, judge_config TO tuner;
