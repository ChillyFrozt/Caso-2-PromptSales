USE PromptCrm;
CREATE OR ALTER VIEW dbo.v_PurchaseAgg AS
SELECT campaign_id_ext, CONVERT(char(7), date_time, 126) AS yyyy_mm, market_id_ext,
       COUNT(*) AS orders, SUM(amount_dec) AS revenue
FROM dbo.Purchase
GROUP BY campaign_id_ext, CONVERT(char(7), date_time, 126), market_id_ext;
SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER, ANSI_NULLS ON;
IF OBJECT_ID('dbo.v_PurchaseAgg_IV','V') IS NOT NULL DROP VIEW dbo.v_PurchaseAgg_IV;
GO
CREATE VIEW dbo.v_PurchaseAgg_IV WITH SCHEMABINDING AS
SELECT p.campaign_id_ext, DATEFROMPARTS(YEAR(p.date_time), MONTH(p.date_time), 1) AS month_start,
       p.market_id_ext, COUNT_BIG(*) AS orders, SUM(CAST(p.amount_dec AS DECIMAL(18,2))) AS revenue
FROM dbo.Purchase AS p
GROUP BY p.campaign_id_ext, DATEFROMPARTS(YEAR(p.date_time), MONTH(p.date_time), 1), p.market_id_ext;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_v_PurchaseAgg_IV' AND object_id=OBJECT_ID('dbo.v_PurchaseAgg_IV'))
  CREATE UNIQUE CLUSTERED INDEX IX_v_PurchaseAgg_IV ON dbo.v_PurchaseAgg_IV(campaign_id_ext, month_start, market_id_ext);
GO
