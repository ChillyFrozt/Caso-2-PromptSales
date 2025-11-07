
-- PromptSales (PostgreSQL) — Core DDL
-- \\c promptsales
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Dimensions
CREATE TABLE IF NOT EXISTS dim_date(
  date_id DATE PRIMARY KEY,
  year INT NOT NULL,
  month INT NOT NULL,
  day INT NOT NULL,
  yyyymm INT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_brand(
  brand_id UUID PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_channel(
  channel_id UUID PRIMARY KEY,
  code TEXT NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_market(
  market_id UUID PRIMARY KEY,
  iso_code CHAR(2) NOT NULL,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_campaign(
  campaign_id UUID PRIMARY KEY,
  brand_id UUID NOT NULL REFERENCES dim_brand(brand_id),
  name TEXT NOT NULL,
  objective TEXT,
  start_date DATE NOT NULL,
  end_date DATE,
  currency CHAR(3) NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_influencer(
  influencer_id UUID PRIMARY KEY,
  handle TEXT NOT NULL,
  channel_id UUID NOT NULL REFERENCES dim_channel(channel_id),
  audience_size BIGINT
);

-- Facts
CREATE TABLE IF NOT EXISTS fact_campaign_perf(
  date_id DATE NOT NULL REFERENCES dim_date(date_id),
  campaign_id UUID NOT NULL REFERENCES dim_campaign(campaign_id),
  channel_id UUID NOT NULL REFERENCES dim_channel(channel_id),
  market_id UUID NOT NULL REFERENCES dim_market(market_id),
  impressions BIGINT DEFAULT 0,
  views BIGINT DEFAULT 0,
  clicks BIGINT DEFAULT 0,
  reactions BIGINT DEFAULT 0,
  conversions BIGINT DEFAULT 0,
  cost NUMERIC(18,2) DEFAULT 0,
  revenue NUMERIC(18,2) DEFAULT 0,
  PRIMARY KEY(date_id, campaign_id, channel_id, market_id)
);

CREATE TABLE IF NOT EXISTS fact_sales(
  date_id DATE NOT NULL REFERENCES dim_date(date_id),
  campaign_id UUID NOT NULL REFERENCES dim_campaign(campaign_id),
  market_id UUID NOT NULL REFERENCES dim_market(market_id),
  amount NUMERIC(18,2) NOT NULL,
  orders BIGINT NOT NULL,
  PRIMARY KEY(date_id, campaign_id, market_id)
);

CREATE TABLE IF NOT EXISTS fact_sentiment(
  date_id DATE NOT NULL REFERENCES dim_date(date_id),
  ad_id UUID NOT NULL,
  channel_id UUID NOT NULL REFERENCES dim_channel(channel_id),
  market_id UUID NOT NULL REFERENCES dim_market(market_id),
  neg_events BIGINT NOT NULL DEFAULT 0,
  avg_neg_score NUMERIC(9,6) NOT NULL DEFAULT 0,
  PRIMARY KEY(date_id, ad_id, channel_id, market_id)
);

-- Operational / Logging
CREATE TABLE IF NOT EXISTS etl_runs(
  etl_run_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'running',
  rows_in BIGINT DEFAULT 0,
  rows_out BIGINT DEFAULT 0,
  deltas_applied BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ai_usage_log(
  log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  "when" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  student_name TEXT NOT NULL,
  prompt TEXT NOT NULL,
  result_summary TEXT,
  validation_method TEXT
);

-- Indexes to speed up dashboards
CREATE INDEX IF NOT EXISTS IX_fcp_campaign_date ON fact_campaign_perf (campaign_id, date_id);
CREATE INDEX IF NOT EXISTS IX_fcp_channel_market ON fact_campaign_perf (channel_id, market_id);
CREATE INDEX IF NOT EXISTS IX_fs_campaign_date ON fact_sales (campaign_id, date_id);

-- Example materialized view for KPIs
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_campaign_kpis AS
SELECT c.campaign_id,
       d.year, d.month,
       SUM(f.impressions) AS impressions,
       SUM(f.clicks) AS clicks,
       SUM(f.conversions) AS conversions,
       SUM(f.revenue) AS revenue,
       SUM(f.cost) AS cost,
       CASE WHEN SUM(f.clicks)=0 THEN 0
            ELSE SUM(f.conversions)::NUMERIC/SUM(f.clicks) END AS conv_per_click
FROM fact_campaign_perf f
JOIN dim_date d ON d.date_id = f.date_id
JOIN dim_campaign c ON c.campaign_id = f.campaign_id
GROUP BY c.campaign_id, d.year, d.month;

-- Refresh helper
CREATE OR REPLACE FUNCTION refresh_mv_campaign_kpis() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_campaign_kpis;
END$$;
