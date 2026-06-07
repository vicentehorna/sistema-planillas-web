/*
    Periodos tributarios PLAME por compañía (YYYY-MM).
    Usado por: GET /api/selectores/periodos-plame (plame_archivo14.html y otros).

    id (prperiod): YYYYMM — se envía al listado/generación PLAME.
    text (description): YYYY-MM — etiqueta en el selector.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_plame_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        SUBSTRING(pr_period.prperiod, 1, 4) + '-' + SUBSTRING(pr_period.prperiod, 5, 2) AS description,
        SUBSTRING(pr_period.prperiod, 1, 4) + SUBSTRING(pr_period.prperiod, 5, 2) AS prperiod,
        pr_period.company AS company
    FROM PR_Period pr_period (NOLOCK)
    WHERE SUBSTRING(pr_period.prperiod, 1, 4) <= CONVERT(VARCHAR(4), DATEADD(YEAR, 1, GETDATE()), 112)
      AND pr_period.company = @cia
    ORDER BY description DESC;
END
GO
