/*
    PLAME por Trabajador — detalle de conceptos calculados por proceso/PDT.

    Útil para auditar por qué un PDT del Archivo 18 suma más de un proceso
    (p.ej. LIQUIDACION + PROVISION CTS).

    Filtros:
      @company, @payrolltype, @period (YYYYMM), @person (obligatorio)
      @pdt opcional (vacío = todos)

    Resultset: processname, processshort, formulacode, conceptname, pdt, importe

    Usado por: POST /api/plame/por-trabajador
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporte_plame_por_trabajador_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20),
    @pdt         VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @pdt = LTRIM(RTRIM(ISNULL(@pdt, '')));

    /* Acepta YYYYMM o YYYY-MM */
    SET @period = REPLACE(@period, '-', '');
    IF LEN(@period) >= 6
        SET @period = LEFT(@period, 6);

    IF @company = '' OR @payrolltype = '' OR @period = '' OR LEN(@period) <> 6 OR @person = ''
    BEGIN
        RAISERROR('Indique compañía, planilla, periodo (YYYYMM) y trabajador.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(ISNULL(pt.Description, pt.ShortName))) AS processname,
        LTRIM(RTRIM(ISNULL(pt.ShortName, ''))) AS processshort,
        LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) AS formulacode,
        LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(c.PrintText)), ''), c.Description))) AS conceptname,
        LTRIM(RTRIM(ISNULL(c.PDT, ''))) AS pdt,
        CAST(ROUND(ISNULL(epc.ConceptValueLo, ISNULL(epc.ConceptValue, 0)), 2) AS DECIMAL(18, 2)) AS importe,
        LTRIM(RTRIM(epc.PRPeriod)) AS prperiod,
        LTRIM(RTRIM(epc.ProcessType)) AS processtype,
        LTRIM(RTRIM(epc.Concept)) AS concept
    FROM PR_EmployeePayRollConcept epc (NOLOCK)
    INNER JOIN PR_Concept c (NOLOCK)
        ON c.Company = epc.Company
       AND c.Concept = epc.Concept
    INNER JOIN PR_ProcessType pt (NOLOCK)
        ON pt.ProcessType = epc.ProcessType
    WHERE epc.Company = @company
      AND epc.PayRollType = @payrolltype
      AND epc.Person = @person
      AND LEFT(LTRIM(RTRIM(epc.PRPeriod)), 6) = @period
      AND (@pdt = '' OR LTRIM(RTRIM(ISNULL(c.PDT, ''))) = @pdt)
      AND ABS(ISNULL(epc.ConceptValueLo, ISNULL(epc.ConceptValue, 0))) > 0.0001
    ORDER BY
        processname,
        formulacode,
        conceptname,
        epc.PRPeriod;
END
GO
