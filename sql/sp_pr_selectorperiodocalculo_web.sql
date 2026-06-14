/*
    Selector de periodos de cálculo por compañía y proceso.
    Periodos abiertos o cerrados en PR_ProcessControl (status A, C, G).
    Usado por: GET /api/procesar-planilla/periodos-calculo (procesar_planilla.html).

    processtype, prperiod, description, company
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodocalculo_web]
    @cia         VARCHAR(4),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));

    SELECT DISTINCT
        PC.ProcessType AS processtype,
        PC.PRPeriod AS prperiod,
        SUBSTRING(PC.PRPeriod, 1, 4) + '-'
            + SUBSTRING(PC.PRPeriod, 5, 2) + '-'
            + SUBSTRING(PC.PRPeriod, 7, 2) AS description,
        PC.Company AS company
    FROM PR_ProcessControl PC (NOLOCK)
    WHERE PC.Status IN ('A', 'C', 'G')
      AND PC.Company = @cia
      AND PC.ProcessType = @processtype
    ORDER BY PC.PRPeriod DESC;
END
GO
