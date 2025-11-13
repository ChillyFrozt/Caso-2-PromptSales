/* Cifrado X.509 de PII en PromptCrm (idempotente)
   1) Crea Master Key y Certificado en master (si no existen)
   2) Crea Master Key y Symmetric Key en PromptCrm (si no existen)
   3) Cifra columnas PII (ej.: email_pii, phone_pii) hacia *_enc
*/

-- En master (idempotente):
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
  CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng#MasterKey!';

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'PromptCrmCert')
  CREATE CERTIFICATE PromptCrmCert WITH SUBJECT = 'PromptCrm PII Certificate';

-- En DB PromptCrm:
USE PromptCrm;

IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
  CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Another#DbKey!';

IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'PromptCrmSymKey')
  CREATE SYMMETRIC KEY PromptCrmSymKey
  WITH ALGORITHM = AES_256
  ENCRYPTION BY CERTIFICATE PromptCrmCert;

IF COL_LENGTH('dbo.Customer','email_enc') IS NULL
  ALTER TABLE dbo.Customer ADD email_enc VARBINARY(512) NULL;

IF COL_LENGTH('dbo.Customer','phone_enc') IS NULL
  ALTER TABLE dbo.Customer ADD phone_enc VARBINARY(256) NULL;

OPEN SYMMETRIC KEY PromptCrmSymKey DECRYPTION BY CERTIFICATE PromptCrmCert;

UPDATE c
SET
  email_enc = EncryptByKey(Key_GUID('PromptCrmSymKey'), CONVERT(NVARCHAR(200), c.email_pii)),
  phone_enc = EncryptByKey(Key_GUID('PromptCrmSymKey'), CONVERT(NVARCHAR(50),  c.phone_pii))
FROM dbo.Customer c;

-- Demo lectura (mientras la llave esté abierta)
SELECT TOP 5
  customer_id,
  CONVERT(NVARCHAR(200), DecryptByKey(email_enc)) AS email_plain,
  CONVERT(NVARCHAR(50),  DecryptByKey(phone_enc)) AS phone_plain
FROM dbo.Customer;

CLOSE SYMMETRIC KEY PromptCrmSymKey;

-- Nota: en un restore en otro servidor sin importar el certificado privado,
-- DecryptByKey devolverá NULL.
