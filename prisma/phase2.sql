-- Phase 2: telemetry layer, extra columns, roles, grants. Safe to re-run.
-- Run in Supabase SQL Editor, choose "Run and enable RLS".

-- ---------- extra columns on existing tables ----------
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS vertical_family TEXT;
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS evidence_grade TEXT;
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS kill_criteria JSONB;
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS margin_of_defeat DOUBLE PRECISION;
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS runs_survived INT NOT NULL DEFAULT 0;
ALTER TABLE ideas ADD COLUMN IF NOT EXISTS cut_at_run INT;

ALTER TABLE search_config ADD COLUMN IF NOT EXISTS max_per_family INT NOT NULL DEFAULT 2;
ALTER TABLE search_config ADD COLUMN IF NOT EXISTS min_active_floor INT NOT NULL DEFAULT 8;
ALTER TABLE search_config ADD COLUMN IF NOT EXISTS axis_weights JSONB NOT NULL
  DEFAULT '{"A":1,"B":1,"C":1,"D":1,"E":1,"F":1,"G":1}';

ALTER TABLE cycle_metrics ADD COLUMN IF NOT EXISTS shortfall_count INT NOT NULL DEFAULT 0;
ALTER TABLE cycle_metrics ADD COLUMN IF NOT EXISTS telemetry_degraded BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE cycle_metrics ADD COLUMN IF NOT EXISTS search_config_version INT;
ALTER TABLE cycle_metrics ADD COLUMN IF NOT EXISTS judge_config_version INT;

-- ---------- telemetry + human tables ----------
CREATE TABLE IF NOT EXISTS search_runs (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, seed_axis TEXT, subfocus TEXT, geography TEXT,
  search_config_version INT, prompt_version TEXT, candidates_returned INT,
  grade_distribution JSONB, rejected_reproposals INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS judgment_events (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, idea_id TEXT,
  is_rejudge BOOLEAN NOT NULL DEFAULT false, is_anchor BOOLEAN NOT NULL DEFAULT false,
  dimension_scores JSONB, dimension_confidences JSONB, dimension_evidence JSONB,
  red_flags JSONB, composite_raw DOUBLE PRECISION, judge_config_version INT,
  judge_model TEXT, judge_temperature DOUBLE PRECISION, prompt_version TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS cut_events (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, idea_id TEXT, bucket TEXT,
  composite DOUBLE PRECISION, margin_of_defeat DOUBLE PRECISION, kill_criteria JSONB,
  newcomer_verdict TEXT, judge_config_version INT, created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS revival_events (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, idea_id TEXT, source TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS rejudge_pairs (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, idea_id TEXT,
  composite_a DOUBLE PRECISION, composite_b DOUBLE PRECISION, judge_config_version INT,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS red_flag_events (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, idea_id TEXT, flag TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS anchor_ideas (
  id SERIAL PRIMARY KEY, name TEXT NOT NULL, description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS anchor_judgments (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, anchor_id INT,
  dimension_scores JSONB, composite_raw DOUBLE PRECISION, judge_config_version INT,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS composite_deltas (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, idea_id TEXT,
  previous DOUBLE PRECISION, current DOUBLE PRECISION,
  created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS human_labels (
  id SERIAL PRIMARY KEY, idea_id TEXT, label TEXT, notes TEXT,
  created_by TEXT, created_at TIMESTAMP NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS worker_health (
  id SERIAL PRIMARY KEY, iteration INT NOT NULL, telemetry_writes INT NOT NULL DEFAULT 0,
  telemetry_failures INT NOT NULL DEFAULT 0, created_at TIMESTAMP NOT NULL DEFAULT now());

-- ---------- roles ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='worker')   THEN CREATE ROLE worker   NOINHERIT; END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='reporter') THEN CREATE ROLE reporter NOINHERIT; END IF;
END $$;
-- Set real passwords yourself, e.g.:
--   ALTER ROLE worker   LOGIN PASSWORD '...';
--   ALTER ROLE reporter LOGIN PASSWORD '...';

GRANT USAGE ON SCHEMA public TO worker, reporter, tuner;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO worker, tuner;

-- worker: read config + anchors, own ideas/cycle_metrics, insert-only telemetry
GRANT SELECT ON search_config, judge_config, anchor_ideas TO worker;
GRANT SELECT, INSERT, UPDATE ON ideas, cycle_metrics TO worker;
GRANT SELECT, INSERT ON search_runs, judgment_events, cut_events, revival_events,
  rejudge_pairs, red_flag_events, anchor_judgments, composite_deltas, worker_health TO worker;
REVOKE UPDATE, DELETE ON search_config, judge_config, anchor_ideas FROM worker;
REVOKE INSERT, UPDATE, DELETE ON human_labels FROM worker;

-- tuner: config + labels + anchors
GRANT SELECT, INSERT, UPDATE ON search_config, judge_config, human_labels TO tuner;
GRANT SELECT, INSERT ON anchor_ideas TO tuner;

-- reporter: read everything
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporter;

-- ---------- RLS ----------
DO $$
DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY['search_runs','judgment_events','cut_events','revival_events',
    'rejudge_pairs','red_flag_events','anchor_ideas','anchor_judgments','composite_deltas',
    'human_labels','worker_health']) LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- worker policies (insert/select on telemetry)
DO $$
DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY['search_runs','judgment_events','cut_events','revival_events',
    'rejudge_pairs','red_flag_events','anchor_judgments','composite_deltas','worker_health']) LOOP
    EXECUTE format('DROP POLICY IF EXISTS worker_rw ON %I', t);
    EXECUTE format('CREATE POLICY worker_rw ON %I FOR ALL TO worker USING (true) WITH CHECK (true)', t);
  END LOOP;
END $$;
DROP POLICY IF EXISTS worker_read ON anchor_ideas;
CREATE POLICY worker_read ON anchor_ideas FOR SELECT TO worker USING (true);

-- tuner policies
DO $$
DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY['human_labels','anchor_ideas']) LOOP
    EXECUTE format('DROP POLICY IF EXISTS tuner_all ON %I', t);
    EXECUTE format('CREATE POLICY tuner_all ON %I FOR ALL TO tuner USING (true) WITH CHECK (true)', t);
  END LOOP;
END $$;

-- reporter policies (read everything)
DO $$
DECLARE t TEXT;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS reporter_read ON %I', t);
    EXECUTE format('CREATE POLICY reporter_read ON %I FOR SELECT TO reporter USING (true)', t);
  END LOOP;
END $$;
