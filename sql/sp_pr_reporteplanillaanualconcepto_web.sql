/*
    Planilla Anual por Concepto (RPR034).
    Basado en DW PowerBuilder "Reporte Mensual / Anual - Por Concepto".

    Pivot por mes calendario (ene..dic) dentro del rango de periodos.
    @period_ini / @period_fin en formato YYYYMM; máximo 12 meses.
    Incluye todos los conceptos (con o sin FlagPayrollTicket).

    Agrupación esperada en UI: concepto → trabajadores → total concepto → total general.

    Usado por: POST /api/reportes/planilla-anual-concepto
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplanillaanualconcepto_web]
    @company       VARCHAR(4),
    @period_ini    VARCHAR(6),
    @period_fin    VARCHAR(6),
    @processtype   VARCHAR(20),
    @payrolltype   VARCHAR(20) = '0',
    @person        VARCHAR(20) = '0',
    @concept       VARCHAR(20) = '0',
    @repunit       VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period_ini = LTRIM(RTRIM(ISNULL(@period_ini, '')));
    SET @period_fin = LTRIM(RTRIM(ISNULL(@period_fin, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '0')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '0')));
    SET @repunit = LTRIM(RTRIM(ISNULL(@repunit, '0')));

    IF @payrolltype = '' SET @payrolltype = '0';
    IF @person = '' SET @person = '0';
    IF @concept = '' SET @concept = '0';
    IF @repunit = '' SET @repunit = '0';

    IF @company = '' OR @processtype = ''
       OR @period_ini = '' OR @period_fin = ''
       OR LEN(@period_ini) NOT IN (6, 8) OR LEN(@period_fin) NOT IN (6, 8)
       OR ISNUMERIC(@period_ini) = 0 OR ISNUMERIC(@period_fin) = 0
    BEGIN
        RAISERROR('Indique compañía, proceso y rango de periodos (YYYYMM / YYYYMMDD).', 16, 1);
        RETURN;
    END;

    -- Normalizar a YYYYMM (en varias BD PRPeriod es YYYYMMDD, p.ej. 20260101)
    SET @period_ini = LEFT(@period_ini, 6);
    SET @period_fin = LEFT(@period_fin, 6);

    IF @period_fin < @period_ini
    BEGIN
        RAISERROR('El periodo final no puede ser menor que el inicial.', 16, 1);
        RETURN;
    END;

    DECLARE @y1 INT = CAST(LEFT(@period_ini, 4) AS INT);
    DECLARE @m1 INT = CAST(RIGHT(@period_ini, 2) AS INT);
    DECLARE @y2 INT = CAST(LEFT(@period_fin, 4) AS INT);
    DECLARE @m2 INT = CAST(RIGHT(@period_fin, 2) AS INT);

    IF @m1 < 1 OR @m1 > 12 OR @m2 < 1 OR @m2 > 12
    BEGIN
        RAISERROR('Mes de periodo inválido (01-12).', 16, 1);
        RETURN;
    END;

    IF ((@y2 - @y1) * 12 + (@m2 - @m1) + 1) > 12
    BEGIN
        RAISERROR('El rango de periodos no puede superar 12 meses.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(ISNULL(c.Concept, ''))) AS concept,
        LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(c.PrintText)), ''), c.Description))) AS conceptname,
        LTRIM(RTRIM(e.Person)) AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS personname,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '01'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS ene,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '02'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS feb,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '03'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS mar,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '04'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS abr,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '05'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS may,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '06'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS jun,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '07'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS jul,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '08'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS ago,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '09'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS sep,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '10'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS oct,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '11'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS nov,
        CAST(SUM(CASE WHEN SUBSTRING(LTRIM(RTRIM(epc.PRPeriod)), 5, 2) = '12'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS dic
    FROM PR_EmployeePayRollConcept epc (NOLOCK)
    INNER JOIN PR_Employee e (NOLOCK)
        ON e.Person = epc.Person
       AND e.Company = epc.Company
    INNER JOIN SY_Person sp (NOLOCK)
        ON sp.Person = e.Person
    INNER JOIN PR_Concept c (NOLOCK)
        ON c.Company = epc.Company
       AND c.Concept = epc.Concept
    WHERE epc.Company = @company
      AND e.Company = @company
      AND c.Company = @company
      AND epc.ProcessType = @processtype
      AND LEFT(LTRIM(RTRIM(epc.PRPeriod)), 6) BETWEEN @period_ini AND @period_fin
      AND (@payrolltype = '0' OR epc.PayRollType = @payrolltype)
      AND (@person = '0' OR epc.Person = @person)
      AND (@concept = '0' OR epc.Concept = @concept)
      AND (@repunit = '0' OR sp.ReplicationUnit = @repunit)
    GROUP BY
        c.Concept,
        c.PrintText, c.Description,
        e.Person,
        sp.LastName1, sp.LastName2, sp.Name1, sp.Name2
    HAVING
        SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue)) <> 0
    ORDER BY
        conceptname,
        personname,
        e.Person;
END
GO
