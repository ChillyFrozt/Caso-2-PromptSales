-- Ajusta servidor/credenciales antes de ejecutar en PromptCrm
EXEC sp_addlinkedserver @server=N'PROMPTADS', @srvproduct=N'', @provider=N'SQLNCLI', @datasrc=N'SRV_ADS', @catalog=N'PromptAds';
EXEC sp_addlinkedsrvlogin @rmtsrvname=N'PROMPTADS', @useself='FALSE', @locallogin=NULL, @rmtuser=N'ads_user', @rmtpassword=N'ads_pwd';
-- SELECT TOP 5 name, status FROM PROMPTADS.PromptAds.dbo.Campaign;
