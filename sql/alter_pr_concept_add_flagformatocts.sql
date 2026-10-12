/*
    Agrega flag Formato de CTS en PR_Concept (maestro Conceptos).
    Usado por: sp_pr_guardarconcepto_web, sp_pr_obtenerconcepto_web,
               sp_pr_control_datos_cts_persona (remuneración computable del formato de CTS).
*/
IF OBJECT_ID(N'dbo.PR_Concept', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Concept', 'flagformatocts') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_Concept ADD flagformatocts CHAR(1) NOT NULL CONSTRAINT DF_PR_Concept_flagformatocts DEFAULT (''N'')');
END
GO
