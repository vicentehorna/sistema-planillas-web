/*
    Selector de periodos distintos por compañía (PR_ProcessControl).
    Usado por: GET /api/selectores/periodos-cia (reporte planilla por conceptos).

    id: period (PRPERIOD, YYYYMMDD)
    text: periodo (YYYY-MM-DD)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_cia_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT DISTINCT
        PC.PRPeriod AS period,
        SUBSTRING(PC.PRPeriod, 1, 4) + '-'
            + SUBSTRING(PC.PRPeriod, 5, 2) + '-'
            + SUBSTRING(PC.PRPeriod, 7, 2) AS periodo
    FROM PR_ProcessControl PC (NOLOCK)
    WHERE PC.Status IN ('A', 'C', 'G')
      AND PC.Company = @cia
      AND LEN(LTRIM(RTRIM(ISNULL(PC.PRPeriod, '')))) = 8
    ORDER BY PC.PRPeriod DESC;
END
GO
