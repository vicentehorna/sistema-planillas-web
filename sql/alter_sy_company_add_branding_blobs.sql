/*
    Branding por compañía: logo y firma en VARBINARY (autoservicio web).
    Compatible con logoname / signaturename existentes (nombre original / fallback static/img).
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'logo_data') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD logo_data VARBINARY(MAX) NULL');
END
GO

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'signature_data') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD signature_data VARBINARY(MAX) NULL');
END
GO

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'logo_contenttype') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD logo_contenttype VARCHAR(50) NULL');
END
GO

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'signature_contenttype') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD signature_contenttype VARCHAR(50) NULL');
END
GO
