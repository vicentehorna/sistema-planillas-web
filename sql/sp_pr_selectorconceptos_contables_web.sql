/*
    Selector de conceptos monetarios por compañía (para configuración contable).
    Usado por: POST /api/asientos/configurar-conceptos/conceptos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorconceptos_contables_web]
    @company   VARCHAR(4),
    @busqueda  VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(c.Concept)) AS id,
        LTRIM(RTRIM(ISNULL(c.Description, c.Concept))) AS text,
        LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) AS formulacode
    FROM PR_Concept c (NOLOCK)
    WHERE c.Company = @company
      AND ISNULL(c.Status, 'A') = 'A'
      AND ISNULL(c.FlagIsMonetary, 'Y') = 'Y'
      AND (
            @busqueda IS NULL
         OR ISNULL(c.Description, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(c.FormulaCode, '') LIKE '%' + @busqueda + '%'
      )
    ORDER BY c.Description ASC, c.FormulaCode ASC;
END
GO
