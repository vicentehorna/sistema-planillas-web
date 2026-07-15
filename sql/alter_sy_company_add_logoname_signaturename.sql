/*
    Agrega columnas de logo y firma por compañía en SY_Company.
    Usado por: generación de boletas PDF (static/img + logoname / signaturename).
*/
IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'logoname') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD logoname VARCHAR(100) NULL');
END
GO

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'signaturename') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD signaturename VARCHAR(100) NULL');
END
GO
