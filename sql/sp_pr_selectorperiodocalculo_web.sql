/*
    Selector de periodos de cálculo por compañía, planilla y proceso.
    Periodos abiertos o cerrados en PR_ProcessControl (status A, C, G)
    de la planilla indicada (no mezcla otras planillas).
    Usado por: GET /api/procesar-planilla/periodos-calculo (procesar_planilla.html).

    processtype, prperiod, description, company, status
    Orden: abiertos (A/G) primero, luego PRPeriod DESC.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodocalculo_web]
    @cia         VARCHAR(4),
    @processtype VARCHAR(20),
    @payrolltype VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        PC.ProcessType AS processtype,
        PC.PRPeriod AS prperiod,
        SUBSTRING(PC.PRPeriod, 1, 4) + '-'
            + SUBSTRING(PC.PRPeriod, 5, 2) + '-'
            + SUBSTRING(PC.PRPeriod, 7, 2) AS description,
        PC.Company AS company,
        LTRIM(RTRIM(ISNULL(PC.Status, ''))) AS status
    FROM PR_ProcessControl PC (NOLOCK)
    WHERE PC.Status IN ('A', 'C', 'G')
      AND PC.Company = @cia
      AND PC.ProcessType = @processtype
      AND (@payrolltype = '' OR PC.PayRollType = @payrolltype)
    ORDER BY
        CASE LTRIM(RTRIM(ISNULL(PC.Status, '')))
            WHEN 'A' THEN 0
            WHEN 'G' THEN 0
            ELSE 1
        END,
        PC.PRPeriod DESC;
END
GO
