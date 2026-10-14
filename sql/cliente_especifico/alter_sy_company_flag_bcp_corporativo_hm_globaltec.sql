/*
    hm_globaltec: indicador de Telecrédito BCP formato corporativo.
    Y = cabecera #1H y detalle del ejemplo Telecredito-20260930.txt.
    N = cabecera estándar que inicia en 1.
    No se muestra en el maestro de empresas.
    Se activa en GLOBALTEC S.A.C. (BGT), dueña de la cuenta 19100212594013.
*/
SET NOCOUNT ON;

IF COL_LENGTH('dbo.SY_Company', 'FlagBcpCorporativo') IS NULL
    ALTER TABLE dbo.SY_Company
        ADD FlagBcpCorporativo CHAR(1) NOT NULL
            CONSTRAINT DF_SY_Company_FlagBcpCorporativo DEFAULT ('N');
GO

UPDATE dbo.SY_Company
SET FlagBcpCorporativo = 'N'
WHERE FlagBcpCorporativo IS NULL
   OR LTRIM(RTRIM(FlagBcpCorporativo)) = '';

UPDATE dbo.SY_Company
SET FlagBcpCorporativo = 'Y'
WHERE Company = 'BGT';
GO
