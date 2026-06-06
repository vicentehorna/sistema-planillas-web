/*
    Agrega la columna BanbifBank en PR_Mapping y la inicializa
    con el código de banco de ERP_Bank (BANCO BANBIF) por compañía.
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_Mapping'
      AND c.name = 'BanbifBank'
)
BEGIN
    ALTER TABLE dbo.PR_Mapping
        ADD BanbifBank VARCHAR(20) NULL;
END
GO

UPDATE PR_Mapping
SET BanbifBank = (
    SELECT bank
    FROM ERP_Bank
    WHERE name = 'BANCO BANBIF'
      AND Company = PR_Mapping.Company
);
GO
