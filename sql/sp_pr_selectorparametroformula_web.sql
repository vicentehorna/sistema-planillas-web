/*
    Selector de parámetros de fórmula (validación tipo V).
    Usado por: GET /api/selectores/parametros-formula
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorparametroformula_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pf.ParametroFormula AS id,
        pf.Name AS text
    FROM PR_ParametroFormula pf (NOLOCK)
    ORDER BY pf.Name ASC;
END
GO
