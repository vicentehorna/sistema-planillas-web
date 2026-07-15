/*
    Agrega flag afecto a utilidades en PR_Concept (maestro Conceptos).
    Usado por: sp_pr_guardarconcepto_web, sp_pr_obtenerconcepto_web.
*/
IF OBJECT_ID(N'dbo.PR_Concept', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Concept', 'flagafectoUtilidad') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_Concept ADD flagafectoUtilidad CHAR(1) NOT NULL CONSTRAINT DF_PR_Concept_flagafectoUtilidad DEFAULT (''N'')');
END
GO
