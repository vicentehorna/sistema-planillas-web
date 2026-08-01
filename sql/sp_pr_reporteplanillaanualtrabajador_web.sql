/*
    Planilla Anual por Trabajador (RPR035).
    Basado en AUXILIARES/reporte35antiguo.txt (DW PowerBuilder).

    Pivot por mes (ene..dic) del año indicado.
    Siempre solo conceptos incluidos en boleta (FlagPayrollTicket = 'Y').
    Tipos de concepto: I, D, A, T (Ingresos, Descuentos, Aportes, Totales).

    Usado por: POST /api/reportes/planilla-anual-trabajador
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplanillaanualtrabajador_web]
    @company       VARCHAR(4),
    @anho          VARCHAR(4),
    @processtype   VARCHAR(20),
    @payrolltype   VARCHAR(20) = '0',
    @person        VARCHAR(20) = '0',
    @concept       VARCHAR(20) = '0',
    @repunit       VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @anho = LTRIM(RTRIM(ISNULL(@anho, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '0')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '0')));
    SET @repunit = LTRIM(RTRIM(ISNULL(@repunit, '0')));

    IF @payrolltype = '' SET @payrolltype = '0';
    IF @person = '' SET @person = '0';
    IF @concept = '' SET @concept = '0';
    IF @repunit = '' SET @repunit = '0';

    IF @company = '' OR @anho = '' OR LEN(@anho) <> 4 OR @processtype = ''
    BEGIN
        RAISERROR('Indique compañía, año (YYYY) y proceso.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(e.Person)) AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS personname,
        LTRIM(RTRIM(ISNULL(ct.ShortName, ''))) AS conceptshort,
        LTRIM(RTRIM(ISNULL(ct.Description, ''))) AS concepttype,
        LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(c.PrintText)), ''), c.Description))) AS conceptname,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '01'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS ene,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '02'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS feb,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '03'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS mar,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '04'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS abr,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '05'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS may,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '06'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS jun,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '07'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS jul,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '08'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS ago,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '09'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS sep,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '10'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS oct,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '11'
                      THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS DECIMAL(18, 4)) AS nov,
        CAST(SUM(CASE WHEN SUBSTRING(epc.PRPeriod, 5, 2) = '12'
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
    INNER JOIN PR_ConceptType ct (NOLOCK)
        ON ct.ConceptType = c.ConceptType
    WHERE epc.Company = @company
      AND e.Company = @company
      AND c.Company = @company
      AND epc.ProcessType = @processtype
      AND LEFT(LTRIM(RTRIM(epc.PRPeriod)), 4) = @anho
      AND ISNULL(c.FlagPayrollTicket, 'N') = 'Y'
      AND ct.ShortName IN ('I', 'D', 'A', 'T')
      AND (@payrolltype = '0' OR epc.PayRollType = @payrolltype)
      AND (@person = '0' OR epc.Person = @person)
      AND (@concept = '0' OR epc.Concept = @concept)
      AND (@repunit = '0' OR sp.ReplicationUnit = @repunit)
    GROUP BY
        e.Person,
        sp.LastName1, sp.LastName2, sp.Name1, sp.Name2,
        ct.ShortName, ct.Description,
        c.PrintText, c.Description
    HAVING
        SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue)) <> 0
    ORDER BY
        personname,
        e.Person,
        CASE ct.ShortName
            WHEN 'A' THEN 1
            WHEN 'D' THEN 2
            WHEN 'I' THEN 3
            WHEN 'T' THEN 4
            ELSE 9
        END,
        conceptname;
END
GO
