/*
    Selector de periodos por compañía, planilla y proceso (PR_ProcessControl).
    Usado por: GET /api/selectores/periodos (reportes, procesar planilla, etc.).

    id: period (PRPERIOD)
    text: periodo (YYYY-MM-DD)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_web]
    @cia VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));

    SELECT
        PC.ProcessType AS processtype,
        PC.PayRollType AS payrolltype,
        PC.PRPeriod AS period,
        SUBSTRING(PC.PRPeriod, 1, 4) + '-'
            + SUBSTRING(PC.PRPeriod, 5, 2) + '-'
            + SUBSTRING(PC.PRPeriod, 7, 2) AS periodo,
        PC.Company AS company
    FROM PR_ProcessControl PC (NOLOCK)
    WHERE PC.Status IN ('A', 'C', 'G')
      AND PC.Company = @cia
      AND PC.PayRollType = @payrolltype
      AND PC.ProcessType = @processtype
    ORDER BY PC.PRPeriod DESC;
END
GO
