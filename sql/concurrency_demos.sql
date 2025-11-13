USE PromptCrm;

IF OBJECT_ID('dbo.Stock','U') IS NULL
BEGIN
  CREATE TABLE dbo.Stock(
    sku NVARCHAR(50) PRIMARY KEY,
    qty INT NOT NULL
  );
  INSERT INTO dbo.Stock(sku, qty) VALUES ('A',100),('B',100),('C',100);
END
GO

-- Deadlock en cascada (corre cada bloque en una sesión distinta):
-- S1:
-- BEGIN TRAN;
-- UPDATE dbo.Stock SET qty=qty+1 WHERE sku='A';
-- WAITFOR DELAY '00:00:05';
-- UPDATE dbo.Stock SET qty=qty+1 WHERE sku='B';
-- COMMIT;

-- S2:
-- BEGIN TRAN;
-- UPDATE dbo.Stock SET qty=qty+1 WHERE sku='B';
-- WAITFOR DELAY '00:00:05';
-- UPDATE dbo.Stock SET qty=qty+1 WHERE sku='C';
-- COMMIT;

-- S3:
-- BEGIN TRAN;
-- UPDATE dbo.Stock SET qty=qty+1 WHERE sku='C';
-- WAITFOR DELAY '00:00:05';
-- UPDATE dbo.Stock SET qty=qty+1 WHERE sku='A';
-- COMMIT;

-- Dirty read (demo):
-- Sesión A: BEGIN TRAN; UPDATE dbo.Stock SET qty=qty+10 WHERE sku='A'; -- no commit
-- Sesión B: SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; SELECT * FROM dbo.Stock WHERE sku='A';
-- Fix: ALTER DATABASE PromptCrm SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;

-- Lost update: proc vulnerable vs seguro
IF OBJECT_ID('dbo.usp_add_qty_vulnerable','P') IS NOT NULL DROP PROC dbo.usp_add_qty_vulnerable;
GO
CREATE PROC dbo.usp_add_qty_vulnerable @sku nvarchar(50), @delta int AS
BEGIN
  DECLARE @q int; SELECT @q = qty FROM dbo.Stock WHERE sku=@sku;
  SET @q = @q + @delta;
  UPDATE dbo.Stock SET qty = @q WHERE sku=@sku;
END;
GO

IF OBJECT_ID('dbo.usp_add_qty_safe','P') IS NOT NULL DROP PROC dbo.usp_add_qty_safe;
GO
CREATE PROC dbo.usp_add_qty_safe @sku nvarchar(50), @delta int AS
BEGIN
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  BEGIN TRAN;
  UPDATE dbo.Stock WITH (ROWLOCK, UPDLOCK)
    SET qty = qty + @delta
    WHERE sku=@sku;
  COMMIT;
END;
GO
