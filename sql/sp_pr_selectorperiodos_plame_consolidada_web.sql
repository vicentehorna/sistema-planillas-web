/*
    Periodos tributarios PLAME distintos en todas las compañías activas (YYYY-MM).
    Usado por: GET /api/selectores/periodos-plame-consolidada (PLAME masivo y otros).

    id (prperiod): YYYYMM — se envía al listado/generación PLAME.
    text (description): YYYY-MM — etiqueta en el selector.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_plame_consolidada_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        SUBSTRING(pr_period.prperiod, 1, 4) + '-' + SUBSTRING(pr_period.prperiod, 5, 2) AS description,
        SUBSTRING(pr_period.prperiod, 1, 4) + SUBSTRING(pr_period.prperiod, 5, 2) AS prperiod
    FROM PR_Period pr_period (NOLOCK)
        INNER JOIN SY_Company sc (NOLOCK)
            ON sc.Company = pr_period.company
           AND sc.status = 'A'
    WHERE SUBSTRING(pr_period.prperiod, 1, 4) <= CONVERT(VARCHAR(4), DATEADD(YEAR, 1, GETDATE()), 112)
    ORDER BY description DESC;
END
GO
