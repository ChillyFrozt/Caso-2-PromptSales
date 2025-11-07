USE PromptCrm;
IF OBJECT_ID('dbo.Stock','U') IS NULL BEGIN
  CREATE TABLE dbo.Stock(sku NVARCHAR(50) PRIMARY KEY, qty INT NOT NULL);
  INSERT INTO dbo.Stock(sku, qty) VALUES ('A',100),('B',100),('C',100);
END
GO
-- Deadlock (3 sesiones): ver README para pasos
-- Dirty read y fix: READ_COMMITTED_SNAPSHOT ON
-- Lost update: procs vulnerable vs. seguro
