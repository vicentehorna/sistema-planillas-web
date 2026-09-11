/*
    Agrega flag Formato Liquidacion en PR_Concept (maestro Conceptos).
    Usado por: sp_pr_guardarconcepto_web, sp_pr_obtenerconcepto_web,
               formato de liquidación (ingresos configurables).
*/
IF OBJECT_ID(N'dbo.PR_Concept', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Concept', 'flagformatoliquidacion') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_Concept ADD flagformatoliquidacion CHAR(1) NOT NULL CONSTRAINT DF_PR_Concept_flagformatoliquidacion DEFAULT (''N'')');
END
GO
