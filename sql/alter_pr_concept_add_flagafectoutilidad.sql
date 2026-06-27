/*
    Agrega flag afecto a utilidades en PR_Concept (maestro Conceptos).
    Usado por: sp_pr_guardarconcepto_web, sp_pr_obtenerconcepto_web.
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_Concept'
      AND c.name = 'flagafectoUtilidad'
)
BEGIN
    ALTER TABLE dbo.PR_Concept
        ADD flagafectoUtilidad CHAR(1) NOT NULL
            CONSTRAINT DF_PR_Concept_flagafectoUtilidad DEFAULT ('N');
END
GO
