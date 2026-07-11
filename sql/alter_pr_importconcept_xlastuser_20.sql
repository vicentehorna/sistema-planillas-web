/*
    Amplía XlastUser de VARCHAR(4) a VARCHAR(20) en plantillas de importación.
    Alineado con SY_ObjectSecuence.XLastUser y el usuario web (_xlastuser_id, 20 chars).

    Tablas: PR_ImportConcept, PR_ImportConceptDetail
    Usado por: sp_pr_guardarimportconcept_web, POST /api/plantillas-importacion/guardar
*/
IF EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_ImportConcept'
      AND c.name = 'XlastUser'
      AND c.max_length <> 20
)
BEGIN
    ALTER TABLE dbo.PR_ImportConcept
        ALTER COLUMN XlastUser VARCHAR(20) NULL;
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_ImportConceptDetail'
      AND c.name = 'XlastUser'
      AND c.max_length <> 20
)
BEGIN
    ALTER TABLE dbo.PR_ImportConceptDetail
        ALTER COLUMN XlastUser VARCHAR(20) NULL;
END
GO
