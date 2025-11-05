
-- PromptCrm (SQL Server) — Core DDL
-- USE [PromptCrm];
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF OBJECT_ID('dbo.Customer','U') IS NULL
CREATE TABLE dbo.Customer(
  customer_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  tenant_id UNIQUEIDENTIFIER NOT NULL,
  name_pii NVARCHAR(200) NOT NULL,
  email_pii NVARCHAR(200) NULL,
  phone_pii NVARCHAR(50) NULL,
  birthdate DATE NULL,
  country CHAR(2) NULL,
  city NVARCHAR(120) NULL,
  consent_flags INT NOT NULL DEFAULT 0,
  created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  is_deleted BIT NOT NULL DEFAULT 0,
  CONSTRAINT PK_Customer PRIMARY KEY CLUSTERED(customer_id)
);
CREATE INDEX IX_Customer_Email ON dbo.Customer(email_pii);
CREATE INDEX IX_Customer_CountryCity ON dbo.Customer(country, city);

IF OBJECT_ID('dbo.Lead','U') IS NULL
CREATE TABLE dbo.Lead(
  lead_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  tenant_id UNIQUEIDENTIFIER NOT NULL,
  source NVARCHAR(100) NOT NULL,
  captured_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  campaign_id_ext UNIQUEIDENTIFIER NULL,
  channel_id_ext UNIQUEIDENTIFIER NULL,
  market_id_ext UNIQUEIDENTIFIER NULL,
  ad_id_ext UNIQUEIDENTIFIER NULL,
  utm_source NVARCHAR(100) NULL,
  utm_medium NVARCHAR(100) NULL,
  utm_campaign NVARCHAR(150) NULL,
  CONSTRAINT PK_Lead PRIMARY KEY CLUSTERED(lead_id)
);
CREATE INDEX IX_Lead_Captured ON dbo.Lead(captured_at);
CREATE INDEX IX_Lead_UTM ON dbo.Lead(utm_source, utm_medium, utm_campaign);

IF OBJECT_ID('dbo.Interaction','U') IS NULL
CREATE TABLE dbo.Interaction(
  interaction_id BIGINT IDENTITY(1,1) NOT NULL,
  customer_id UNIQUEIDENTIFIER NOT NULL,
  lead_id UNIQUEIDENTIFIER NULL,
  date_time DATETIME2(3) NOT NULL,
  channel_code NVARCHAR(50) NOT NULL, -- email|whatsapp|sms|voice|chat
  direction NVARCHAR(10) NOT NULL,    -- in|out
  content_summary NVARCHAR(500) NULL,
  agent_id UNIQUEIDENTIFIER NULL,
  result_code NVARCHAR(50) NULL,
  CONSTRAINT PK_Interaction PRIMARY KEY CLUSTERED(interaction_id),
  CONSTRAINT FK_I_Cust FOREIGN KEY(customer_id) REFERENCES dbo.Customer(customer_id),
  CONSTRAINT FK_I_Lead FOREIGN KEY(lead_id) REFERENCES dbo.Lead(lead_id)
);
CREATE INDEX IX_Interaction_CustDate ON dbo.Interaction(customer_id, date_time DESC);
CREATE INDEX IX_Interaction_LeadDate ON dbo.Interaction(lead_id, date_time DESC);

IF OBJECT_ID('dbo.Purchase','U') IS NULL
CREATE TABLE dbo.Purchase(
  purchase_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  customer_id UNIQUEIDENTIFIER NOT NULL,
  date_time DATETIME2(3) NOT NULL,
  amount_dec DECIMAL(18,2) NOT NULL,
  currency CHAR(3) NOT NULL,
  campaign_id_ext UNIQUEIDENTIFIER NULL,
  ad_id_ext UNIQUEIDENTIFIER NULL,
  market_id_ext UNIQUEIDENTIFIER NULL,
  CONSTRAINT PK_Purchase PRIMARY KEY CLUSTERED(purchase_id),
  CONSTRAINT FK_P_Cust FOREIGN KEY(customer_id) REFERENCES dbo.Customer(customer_id)
);
CREATE INDEX IX_Purchase_CustDate ON dbo.Purchase(customer_id, date_time DESC);
CREATE INDEX IX_Purchase_Campaign ON dbo.Purchase(campaign_id_ext, date_time);

IF OBJECT_ID('dbo.CustomerCampaignMap','U') IS NULL
CREATE TABLE dbo.CustomerCampaignMap(
  customer_id UNIQUEIDENTIFIER NOT NULL,
  campaign_id_ext UNIQUEIDENTIFIER NOT NULL,
  first_seen_at DATETIME2(3) NOT NULL,
  last_seen_at DATETIME2(3) NOT NULL,
  CONSTRAINT PK_CustCamp PRIMARY KEY(customer_id, campaign_id_ext),
  CONSTRAINT FK_CCM_Cust FOREIGN KEY(customer_id) REFERENCES dbo.Customer(customer_id)
);
CREATE INDEX IX_CCM_LastSeen ON dbo.CustomerCampaignMap(last_seen_at);

IF OBJECT_ID('dbo.Address','U') IS NULL
CREATE TABLE dbo.Address(
  address_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  customer_id UNIQUEIDENTIFIER NOT NULL,
  line1 NVARCHAR(200) NOT NULL,
  line2 NVARCHAR(200) NULL,
  city NVARCHAR(120) NOT NULL,
  region NVARCHAR(120) NULL,
  postal_code NVARCHAR(30) NULL,
  country CHAR(2) NOT NULL,
  CONSTRAINT PK_Address PRIMARY KEY CLUSTERED(address_id),
  CONSTRAINT FK_Addr_Cust FOREIGN KEY(customer_id) REFERENCES dbo.Customer(customer_id)
);

IF OBJECT_ID('dbo.ContactChannel','U') IS NULL
CREATE TABLE dbo.ContactChannel(
  contact_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  customer_id UNIQUEIDENTIFIER NOT NULL,
  type NVARCHAR(30) NOT NULL, -- email|phone|whatsapp|telegram|other
  value_pii NVARCHAR(200) NOT NULL,
  is_primary BIT NOT NULL DEFAULT 0,
  CONSTRAINT PK_ContactChannel PRIMARY KEY CLUSTERED(contact_id),
  CONSTRAINT FK_CC_Cust FOREIGN KEY(customer_id) REFERENCES dbo.Customer(customer_id)
);
CREATE UNIQUE INDEX UQ_CC_Primary ON dbo.ContactChannel(customer_id, type) WHERE is_primary = 1;

IF OBJECT_ID('dbo.Consent','U') IS NULL
CREATE TABLE dbo.Consent(
  consent_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  customer_id UNIQUEIDENTIFIER NOT NULL,
  type NVARCHAR(50) NOT NULL,  -- email_marketing|sms_marketing|privacy|tos
  granted BIT NOT NULL,
  granted_at DATETIME2(3) NOT NULL,
  CONSTRAINT PK_Consent PRIMARY KEY CLUSTERED(consent_id),
  CONSTRAINT FK_Consent_Cust FOREIGN KEY(customer_id) REFERENCES dbo.Customer(customer_id)
);
CREATE INDEX IX_Consent_CustType ON dbo.Consent(customer_id, type);

-- For encryption demo (Deliverable 2+): stores certificate thumbprint, etc.
IF OBJECT_ID('dbo.EncryptionKeyRef','U') IS NULL
CREATE TABLE dbo.EncryptionKeyRef(
  enc_id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
  thumbprint NVARCHAR(200) NOT NULL,
  created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_EncKeyRef PRIMARY KEY CLUSTERED(enc_id)
);
