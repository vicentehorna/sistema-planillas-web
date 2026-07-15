/*
    Lista de conceptos para líneas SumaConc (tipo S).
    Valores separados por |, ej: BGT 000000000130|BGT 000000000069
    Si es NULL, se usa el campo Concept (compatibilidad hacia atrás).
*/
IF OBJECT_ID(N'dbo.PR_FormulaDetail', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_FormulaDetail', 'ConceptList') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_FormulaDetail ADD ConceptList VARCHAR(500) NULL');
END
GO
