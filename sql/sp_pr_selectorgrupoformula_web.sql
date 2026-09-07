/*
    Selector de grupos de fórmula por compañía.
    Usado por: GET /api/selectores/grupos-formula
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorgrupoformula_web]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));

    SELECT
        gf.GrupoFormula AS id,
        gf.name AS text,
        gf.grouporder
    FROM PR_GrupoFormula gf (NOLOCK)
    WHERE gf.Company = @company
    ORDER BY gf.grouporder ASC, gf.name ASC;
END
GO
