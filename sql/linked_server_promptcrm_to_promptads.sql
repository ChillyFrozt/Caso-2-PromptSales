-- Ejecutar en la base PromptCrm (instancia que tenga PromptCrm).
-- Ajusta @datasrc y credenciales según tu entorno.

-- Opción recomendada (proveedor moderno):
EXEC sp_addlinkedserver
  @server     = N'PROMPTADS',
  @srvproduct = N'',
  @provider   = N'MSOLEDBSQL',
  @datasrc    = N'SRV_ADS',   -- <== CAMBIA: servidor/instancia de PromptAds
  @catalog    = N'PromptAds';

EXEC sp_addlinkedsrvlogin
  @rmtsrvname = N'PROMPTADS',
  @useself    = 'FALSE',
  @locallogin = NULL,
  @rmtuser    = N'ads_user',      -- <== CAMBIA
  @rmtpassword= N'ads_pwd';       -- <== CAMBIA

-- Alternativa si solo tienes SQLNCLI instalado:
-- EXEC sp_addlinkedserver @server=N'PROMPTADS', @srvproduct=N'', @provider=N'SQLNCLI', @datasrc=N'SRV_ADS', @catalog=N'PromptAds';
-- EXEC sp_addlinkedsrvlogin @rmtsrvname=N'PROMPTADS', @useself='FALSE', @locallogin=NULL, @rmtuser=N'ads_user', @rmtpassword=N'ads_pwd';

-- Prueba:
-- SELECT TOP 5 name, status FROM PROMPTADS.PromptAds.dbo.Campaign;
