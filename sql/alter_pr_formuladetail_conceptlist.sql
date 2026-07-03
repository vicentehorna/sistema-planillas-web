/*
    Lista de conceptos para líneas SumaConc (tipo S).
    Valores separados por |, ej: BGT 000000000130|BGT 000000000069
    Si es NULL, se usa el campo Concept (compatibilidad hacia atrás).
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.PR_FormulaDetail')
      AND name = 'ConceptList'
)
BEGIN
    ALTER TABLE dbo.PR_FormulaDetail
        ADD ConceptList VARCHAR(500) NULL;
END
GO
