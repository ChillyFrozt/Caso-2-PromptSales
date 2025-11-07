
-- PromptAds (SQL Server) — Core DDL (Corrected PK for partitioned table)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-------------------------------------------------------------------------------
-- Partitioning (PerformanceDaily) — monthly from 2024-07 to 2026-01
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'pfDateRange')
BEGIN
    CREATE PARTITION FUNCTION pfDateRange (DATE) AS RANGE RIGHT FOR VALUES (
        '2024-07-01','2024-08-01','2024-09-01','2024-10-01','2024-11-01','2024-12-01',
        '2025-01-01','2025-02-01','2025-03-01','2025-04-01','2025-05-01','2025-06-01',
        '2025-07-01','2025-08-01','2025-09-01','2025-10-01','2025-11-01','2025-12-01',
        '2026-01-01'
    );
END;

IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'psDateRange')
BEGIN
    CREATE PARTITION SCHEME psDateRange AS PARTITION pfDateRange ALL TO ([PRIMARY]);
END;

-------------------------------------------------------------------------------
-- Dimension-like lookup tables
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.Brand','U') IS NULL
CREATE TABLE dbo.Brand(
  brand_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  tenant_id UNIQUEIDENTIFIER NOT NULL,
  name NVARCHAR(200) NOT NULL,
  CONSTRAINT PK_Brand PRIMARY KEY CLUSTERED(brand_id)
);

IF OBJECT_ID('dbo.Channel','U') IS NULL
CREATE TABLE dbo.Channel(
  channel_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  code NVARCHAR(50) NOT NULL UNIQUE,
  name NVARCHAR(100) NOT NULL,
  CONSTRAINT PK_Channel PRIMARY KEY CLUSTERED(channel_id)
);

IF OBJECT_ID('dbo.Market','U') IS NULL
CREATE TABLE dbo.Market(
  market_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  iso_code CHAR(2) NOT NULL,
  name NVARCHAR(120) NOT NULL,
  CONSTRAINT UQ_Market_iso UNIQUE(iso_code),
  CONSTRAINT PK_Market PRIMARY KEY CLUSTERED(market_id)
);

-------------------------------------------------------------------------------
-- Campaign & relations
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.Campaign','U') IS NULL
CREATE TABLE dbo.Campaign(
  campaign_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  tenant_id UNIQUEIDENTIFIER NOT NULL,
  brand_id UNIQUEIDENTIFIER NOT NULL,
  name NVARCHAR(200) NOT NULL,
  objective NVARCHAR(200) NULL,
  start_date DATE NOT NULL,
  end_date   DATE NULL,
  budget_dec DECIMAL(18,2) NOT NULL,
  currency CHAR(3) NOT NULL,
  status NVARCHAR(30) NOT NULL DEFAULT 'active',
  created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at DATETIME2(3) NULL,
  CONSTRAINT PK_Campaign PRIMARY KEY CLUSTERED(campaign_id),
  CONSTRAINT FK_Campaign_Brand FOREIGN KEY(brand_id) REFERENCES dbo.Brand(brand_id)
);
CREATE INDEX IX_Campaign_Status ON dbo.Campaign(status) WHERE status='active';

IF OBJECT_ID('dbo.CampaignChannel','U') IS NULL
CREATE TABLE dbo.CampaignChannel(
  campaign_id UNIQUEIDENTIFIER NOT NULL,
  channel_id UNIQUEIDENTIFIER NOT NULL,
  CONSTRAINT PK_CampaignChannel PRIMARY KEY(campaign_id, channel_id),
  CONSTRAINT FK_CC_C FOREIGN KEY(campaign_id) REFERENCES dbo.Campaign(campaign_id),
  CONSTRAINT FK_CC_Ch FOREIGN KEY(channel_id)  REFERENCES dbo.Channel(channel_id)
);

IF OBJECT_ID('dbo.CampaignMarket','U') IS NULL
CREATE TABLE dbo.CampaignMarket(
  campaign_id UNIQUEIDENTIFIER NOT NULL,
  market_id UNIQUEIDENTIFIER NOT NULL,
  CONSTRAINT PK_CampaignMarket PRIMARY KEY(campaign_id, market_id),
  CONSTRAINT FK_CM_C FOREIGN KEY(campaign_id) REFERENCES dbo.Campaign(campaign_id),
  CONSTRAINT FK_CM_M FOREIGN KEY(market_id)   REFERENCES dbo.Market(market_id)
);

-------------------------------------------------------------------------------
-- Ads & creatives
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.AdCreative','U') IS NULL
CREATE TABLE dbo.AdCreative(
  creative_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  content_ext_provider NVARCHAR(50) NOT NULL,
  content_ext_id NVARCHAR(200) NOT NULL,
  mime_type NVARCHAR(100) NULL,
  CONSTRAINT PK_AdCreative PRIMARY KEY CLUSTERED(creative_id)
);

IF OBJECT_ID('dbo.Ad','U') IS NULL
CREATE TABLE dbo.Ad(
  ad_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  campaign_id UNIQUEIDENTIFIER NOT NULL,
  channel_id UNIQUEIDENTIFIER NOT NULL,
  market_id UNIQUEIDENTIFIER NOT NULL,
  name NVARCHAR(200) NOT NULL,
  creative_ref UNIQUEIDENTIFIER NULL,
  cta NVARCHAR(200) NULL,
  status NVARCHAR(30) NOT NULL DEFAULT 'active',
  CONSTRAINT PK_Ad PRIMARY KEY CLUSTERED(ad_id),
  CONSTRAINT FK_Ad_Campaign FOREIGN KEY(campaign_id) REFERENCES dbo.Campaign(campaign_id),
  CONSTRAINT FK_Ad_Channel  FOREIGN KEY(channel_id)  REFERENCES dbo.Channel(channel_id),
  CONSTRAINT FK_Ad_Market   FOREIGN KEY(market_id)   REFERENCES dbo.Market(market_id),
  CONSTRAINT FK_Ad_Creative FOREIGN KEY(creative_ref) REFERENCES dbo.AdCreative(creative_id)
);
CREATE INDEX IX_Ad_Status ON dbo.Ad(status) WHERE status='active';
CREATE INDEX IX_Ad_CampaignChannel ON dbo.Ad(campaign_id, channel_id);
CREATE INDEX IX_Ad_Market ON dbo.Ad(market_id);

-------------------------------------------------------------------------------
-- Daily performance (Fact) — partitioned by [date] and with Clustered Columnstore
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.PerformanceDaily','U') IS NULL
CREATE TABLE dbo.PerformanceDaily(
  perf_id BIGINT IDENTITY(1,1) NOT NULL,
  ad_id UNIQUEIDENTIFIER NOT NULL,
  market_id UNIQUEIDENTIFIER NOT NULL,
  [date] DATE NOT NULL,
  impressions BIGINT NOT NULL DEFAULT 0,
  views BIGINT NOT NULL DEFAULT 0,
  clicks BIGINT NOT NULL DEFAULT 0,
  reactions BIGINT NOT NULL DEFAULT 0,
  likes BIGINT NOT NULL DEFAULT 0,
  shares BIGINT NOT NULL DEFAULT 0,
  comments BIGINT NOT NULL DEFAULT 0,
  conversions BIGINT NOT NULL DEFAULT 0,
  revenue_dec DECIMAL(18,2) NOT NULL DEFAULT 0,
  cost_dec DECIMAL(18,2) NOT NULL DEFAULT 0,
  hours_exposed DECIMAL(18,2) NOT NULL DEFAULT 0,
  created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  -- Primary key must include the partitioning column [date]
  CONSTRAINT PK_PerformanceDaily PRIMARY KEY NONCLUSTERED([date], perf_id),
  CONSTRAINT FK_PD_Ad FOREIGN KEY(ad_id) REFERENCES dbo.Ad(ad_id),
  CONSTRAINT FK_PD_Market FOREIGN KEY(market_id) REFERENCES dbo.Market(market_id)
) ON psDateRange([date]);

-- Clustered Columnstore for analytics
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='CCI_PerformanceDaily' AND object_id=OBJECT_ID('dbo.PerformanceDaily'))
    CREATE CLUSTERED COLUMNSTORE INDEX CCI_PerformanceDaily ON dbo.PerformanceDaily;

-- Helpful nonclustered index for frequent filters
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='IX_PD_AdDate' AND object_id=OBJECT_ID('dbo.PerformanceDaily'))
    CREATE NONCLUSTERED INDEX IX_PD_AdDate ON dbo.PerformanceDaily(ad_id, [date]) INCLUDE (impressions, clicks, conversions, revenue_dec, cost_dec);

-------------------------------------------------------------------------------
-- Sentiment tracking & Influencers
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.SentimentEvent','U') IS NULL
CREATE TABLE dbo.SentimentEvent(
  sentiment_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  ad_id UNIQUEIDENTIFIER NOT NULL,
  channel_id UNIQUEIDENTIFIER NOT NULL,
  market_id UNIQUEIDENTIFIER NOT NULL,
  date_time DATETIME2(3) NOT NULL,
  sentiment_type NVARCHAR(30) NOT NULL,
  score_dec DECIMAL(9,6) NOT NULL,
  notes NVARCHAR(500) NULL,
  CONSTRAINT FK_SE_Ad FOREIGN KEY(ad_id) REFERENCES dbo.Ad(ad_id),
  CONSTRAINT FK_SE_Ch FOREIGN KEY(channel_id) REFERENCES dbo.Channel(channel_id),
  CONSTRAINT FK_SE_Mk FOREIGN KEY(market_id) REFERENCES dbo.Market(market_id)
);
CREATE INDEX IX_SE_Time ON dbo.SentimentEvent(date_time);
CREATE INDEX IX_SE_Ad ON dbo.SentimentEvent(ad_id);

IF OBJECT_ID('dbo.Influencer','U') IS NULL
CREATE TABLE dbo.Influencer(
  influencer_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  handle NVARCHAR(120) NOT NULL,
  channel_id UNIQUEIDENTIFIER NOT NULL,
  audience_size BIGINT NULL,
  CONSTRAINT PK_Influencer PRIMARY KEY CLUSTERED(influencer_id),
  CONSTRAINT FK_Inf_Ch FOREIGN KEY(channel_id) REFERENCES dbo.Channel(channel_id)
);

IF OBJECT_ID('dbo.InfluencerReaction','U') IS NULL
CREATE TABLE dbo.InfluencerReaction(
  react_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  influencer_id UNIQUEIDENTIFIER NOT NULL,
  ad_id UNIQUEIDENTIFIER NOT NULL,
  [date] DATE NOT NULL,
  reaction_score_dec DECIMAL(9,6) NOT NULL,
  reaction_label NVARCHAR(30) NOT NULL,
  engagement_rate_dec DECIMAL(9,6) NULL,
  CONSTRAINT FK_IR_Inf FOREIGN KEY(influencer_id) REFERENCES dbo.Influencer(influencer_id),
  CONSTRAINT FK_IR_Ad FOREIGN KEY(ad_id) REFERENCES dbo.Ad(ad_id)
);
CREATE INDEX IX_IR_InfluencerDate ON dbo.InfluencerReaction(influencer_id, [date]);
CREATE INDEX IX_IR_AdDate ON dbo.InfluencerReaction(ad_id, [date]);

-------------------------------------------------------------------------------
-- Budget & currency
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.BudgetAllocation','U') IS NULL
CREATE TABLE dbo.BudgetAllocation(
  alloc_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  campaign_id UNIQUEIDENTIFIER NOT NULL,
  channel_id UNIQUEIDENTIFIER NOT NULL,
  market_id UNIQUEIDENTIFIER NOT NULL,
  [date] DATE NOT NULL,
  budget_dec DECIMAL(18,2) NOT NULL,
  CONSTRAINT FK_BA_Camp FOREIGN KEY(campaign_id) REFERENCES dbo.Campaign(campaign_id),
  CONSTRAINT FK_BA_Ch FOREIGN KEY(channel_id) REFERENCES dbo.Channel(channel_id),
  CONSTRAINT FK_BA_Mk FOREIGN KEY(market_id) REFERENCES dbo.Market(market_id)
);
CREATE INDEX IX_BA_CampDate ON dbo.BudgetAllocation(campaign_id, [date]);

IF OBJECT_ID('dbo.CurrencyRate','U') IS NULL
CREATE TABLE dbo.CurrencyRate(
  rate_id BIGINT IDENTITY(1,1) PRIMARY KEY,
  [date] DATE NOT NULL,
  currency CHAR(3) NOT NULL,
  usd_rate_dec DECIMAL(18,6) NOT NULL
);
CREATE UNIQUE INDEX UQ_CurrencyRate_DateCur ON dbo.CurrencyRate([date], currency);
