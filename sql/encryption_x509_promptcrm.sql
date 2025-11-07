CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Str0ng#MasterKey!';
CREATE CERTIFICATE PromptCrmCert WITH SUBJECT = 'PromptCrm PII Certificate';
USE PromptCrm;
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name='##MS_DatabaseMasterKey##')
  CREATE MASTER KEY ENCRYPTION BY PASSWORD='Another#DbKey!';
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name='PromptCrmSymKey')
  CREATE SYMMETRIC KEY PromptCrmSymKey WITH ALGORITHM=AES_256 ENCRYPTION BY CERTIFICATE PromptCrmCert;
IF COL_LENGTH('dbo.Customer','email_enc') IS NULL ALTER TABLE dbo.Customer ADD email_enc VARBINARY(512);
IF COL_LENGTH('dbo.Customer','phone_enc') IS NULL ALTER TABLE dbo.Customer ADD phone_enc VARBINARY(256);
OPEN SYMMETRIC KEY PromptCrmSymKey DECRYPTION BY CERTIFICATE PromptCrmCert;
UPDATE c SET email_enc=EncryptByKey(Key_GUID('PromptCrmSymKey'), CONVERT(NVARCHAR(200), c.email_pii)),
             phone_enc=EncryptByKey(Key_GUID('PromptCrmSymKey'), CONVERT(NVARCHAR(50), c.phone_pii))
FROM dbo.Customer c;
SELECT TOP 5 customer_id, CONVERT(NVARCHAR(200), DecryptByKey(email_enc)) AS email_plain,
       CONVERT(NVARCHAR(50), DecryptByKey(phone_enc)) AS phone_plain
FROM dbo.Customer;
CLOSE SYMMETRIC KEY PromptCrmSymKey;
