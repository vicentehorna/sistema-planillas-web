/*
    Soporte tipo K (Código condicional) en el formulador.
    ScriptSource  = texto DSL editable
    CompiledExpr  = expresión SQL compilada al guardar (placeholders #C:# #P:# #A:#)
*/
IF OBJECT_ID(N'dbo.PR_FormulaDetail', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.PR_FormulaDetail', 'ScriptSource') IS NULL
        EXEC('ALTER TABLE dbo.PR_FormulaDetail ADD ScriptSource NVARCHAR(MAX) NULL');

    IF COL_LENGTH('dbo.PR_FormulaDetail', 'CompiledExpr') IS NULL
        EXEC('ALTER TABLE dbo.PR_FormulaDetail ADD CompiledExpr NVARCHAR(MAX) NULL');
END
GO
