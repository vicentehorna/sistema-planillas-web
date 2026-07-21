/*
    Catálogo de parámetros de fórmula (validación tipo V).
    Usado por: sp_pr_obtenerformula_web, sp_pr_selectorparametroformula_web.
*/
IF OBJECT_ID(N'dbo.PR_ParametroFormula', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_ParametroFormula (
        ParametroFormula VARCHAR(20) NOT NULL,
        Name             VARCHAR(50) NULL,
        XLastUser        VARCHAR(20) NULL,
        XLastDate        DATETIME NULL,
        CONSTRAINT PK_PR_ParametroFormula PRIMARY KEY (ParametroFormula)
    );
END
GO

/* Columna en cabecera de fórmula (referenciada por sp_pr_obtenerformula_web). */
IF OBJECT_ID(N'dbo.PR_FormulaHeader', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.PR_FormulaHeader', N'parametroformula') IS NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.PR_FormulaHeader ADD parametroformula VARCHAR(20) NULL');
END
GO
