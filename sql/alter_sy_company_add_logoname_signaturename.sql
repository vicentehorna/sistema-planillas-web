/*
    Agrega columnas de logo y firma por compañía en SY_Company.
    Usado por: generación de boletas PDF (static/img + logoname / signaturename).
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'SY_Company'
      AND c.name = 'logoname'
)
BEGIN
    ALTER TABLE dbo.SY_Company
        ADD logoname VARCHAR(100) NULL;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'SY_Company'
      AND c.name = 'signaturename'
)
BEGIN
    ALTER TABLE dbo.SY_Company
        ADD signaturename VARCHAR(100) NULL;
END
GO
