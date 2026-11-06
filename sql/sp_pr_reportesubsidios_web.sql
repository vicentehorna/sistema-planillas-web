/*
    Reporte de Subsidios (hm_ultra).
    Muestra TOTAL_REM_AFP en los 12 periodos anteriores al periodo filtro
    (ACTUAL-12 .. ACTUAL-1) y la columna Promedio vía sp_pr_FormulaPromedioSubsidios.

    Ejemplo: periodo 20261010 → Oct-2025 .. Set-2026 + promedio.

    Usado por: POST /api/reportes/subsidios
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_reportesubsidios_web
    @company     varchar(20),
    @payrolltype varchar(20),
    @processtype varchar(20),
    @period      varchar(20),
    @person      varchar(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    IF @company = '' OR @payrolltype = '' OR @processtype = '' OR @period = ''
    BEGIN
        RAISERROR('Indique compañía, planilla, proceso y periodo.', 16, 1);
        RETURN;
    END;

    IF @person = '' OR @person = '0'
    BEGIN
        RAISERROR('Seleccione el trabajador.', 16, 1);
        RETURN;
    END;

    DECLARE @formulacode varchar(50) = 'TOTAL_REM_AFP';
    DECLARE @concept varchar(20) = NULL;

    SELECT TOP 1 @concept = Concept
    FROM dbo.PR_Concept (NOLOCK)
    WHERE Company = @company
      AND UPPER(LTRIM(RTRIM(ISNULL(FormulaCode, '')))) = @formulacode
    ORDER BY Concept;

    IF ISNULL(@concept, '') = ''
    BEGIN
        RAISERROR('No existe el concepto TOTAL_REM_AFP en la compañía.', 16, 1);
        RETURN;
    END;

    DECLARE @ord int = NULL;
    SELECT @ord = PeriodOrder
    FROM dbo.PR_Period (NOLOCK)
    WHERE Company = @company
      AND PayRollType = @payrolltype
      AND PRPeriod = @period;

    IF @ord IS NULL
    BEGIN
        RAISERROR('Periodo no encontrado para la planilla indicada.', 16, 1);
        RETURN;
    END;

    /* 12 periodos: ACTUAL-12 .. ACTUAL-1 */
    IF OBJECT_ID('tempdb..#meses') IS NOT NULL DROP TABLE #meses;
    CREATE TABLE #meses (
        idx      int NOT NULL PRIMARY KEY,
        PRPeriod varchar(20) NOT NULL,
        lbl      varchar(20) NOT NULL
    );

    DECLARE @i int = 1;
    DECLARE @po int;
    DECLARE @pp varchar(20);
    DECLARE @mm char(2);
    DECLARE @yy char(4);
    DECLARE @mesnom varchar(3);

    WHILE @i <= 12
    BEGIN
        SET @po = @ord - (13 - @i);  /* i=1 -> ord-12; i=12 -> ord-1 */
        SET @pp = NULL;
        SELECT @pp = PRPeriod
        FROM dbo.PR_Period (NOLOCK)
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND PeriodOrder = @po;

        IF @pp IS NULL
        BEGIN
            RAISERROR('No hay los 12 periodos anteriores al periodo seleccionado.', 16, 1);
            RETURN;
        END;

        SET @yy = LEFT(@pp, 4);
        SET @mm = SUBSTRING(@pp, 5, 2);
        SET @mesnom = CASE @mm
            WHEN '01' THEN 'Ene' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mar'
            WHEN '04' THEN 'Abr' WHEN '05' THEN 'May' WHEN '06' THEN 'Jun'
            WHEN '07' THEN 'Jul' WHEN '08' THEN 'Ago' WHEN '09' THEN 'Set'
            WHEN '10' THEN 'Oct' WHEN '11' THEN 'Nov' WHEN '12' THEN 'Dic'
            ELSE @mm END;

        INSERT INTO #meses (idx, PRPeriod, lbl)
        VALUES (@i, @pp, @mesnom + '-' + @yy);

        SET @i = @i + 1;
    END;

    DECLARE @promedio numeric(19, 4) = 0;
    IF OBJECT_ID('dbo.sp_pr_FormulaPromedioSubsidios', 'P') IS NOT NULL
    BEGIN
        EXEC dbo.sp_pr_FormulaPromedioSubsidios
            @cia = @company,
            @person = @person,
            @payrolltype = @payrolltype,
            @processtype = @processtype,
            @period = @period,
            @formulacode = @formulacode,
            @result = @promedio OUTPUT;
    END;

    SELECT
        LTRIM(RTRIM(e.Person)) AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS personname,
        MAX(CASE WHEN m.idx = 1 THEN m.lbl END) AS lbl01,
        MAX(CASE WHEN m.idx = 2 THEN m.lbl END) AS lbl02,
        MAX(CASE WHEN m.idx = 3 THEN m.lbl END) AS lbl03,
        MAX(CASE WHEN m.idx = 4 THEN m.lbl END) AS lbl04,
        MAX(CASE WHEN m.idx = 5 THEN m.lbl END) AS lbl05,
        MAX(CASE WHEN m.idx = 6 THEN m.lbl END) AS lbl06,
        MAX(CASE WHEN m.idx = 7 THEN m.lbl END) AS lbl07,
        MAX(CASE WHEN m.idx = 8 THEN m.lbl END) AS lbl08,
        MAX(CASE WHEN m.idx = 9 THEN m.lbl END) AS lbl09,
        MAX(CASE WHEN m.idx = 10 THEN m.lbl END) AS lbl10,
        MAX(CASE WHEN m.idx = 11 THEN m.lbl END) AS lbl11,
        MAX(CASE WHEN m.idx = 12 THEN m.lbl END) AS lbl12,
        CAST(MAX(CASE WHEN m.idx = 1 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m01,
        CAST(MAX(CASE WHEN m.idx = 2 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m02,
        CAST(MAX(CASE WHEN m.idx = 3 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m03,
        CAST(MAX(CASE WHEN m.idx = 4 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m04,
        CAST(MAX(CASE WHEN m.idx = 5 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m05,
        CAST(MAX(CASE WHEN m.idx = 6 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m06,
        CAST(MAX(CASE WHEN m.idx = 7 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m07,
        CAST(MAX(CASE WHEN m.idx = 8 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m08,
        CAST(MAX(CASE WHEN m.idx = 9 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m09,
        CAST(MAX(CASE WHEN m.idx = 10 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m10,
        CAST(MAX(CASE WHEN m.idx = 11 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m11,
        CAST(MAX(CASE WHEN m.idx = 12 THEN ISNULL(epc.ConceptValueLo, epc.ConceptValue) ELSE 0 END) AS decimal(19, 4)) AS m12,
        CAST(
            ISNULL(SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue)), 0)
            AS decimal(19, 4)
        ) AS total,
        CAST(ISNULL(@promedio, 0) AS decimal(19, 4)) AS promedio
    FROM dbo.PR_Employee e (NOLOCK)
    INNER JOIN dbo.SY_Person sp (NOLOCK)
        ON sp.Person = e.Person
    CROSS JOIN #meses m
    LEFT JOIN dbo.PR_EmployeePayRollConcept epc (NOLOCK)
        ON epc.Company = e.Company
       AND epc.PayRollType = e.PayRollType
       AND epc.Person = e.Person
       AND epc.ProcessType = @processtype
       AND epc.Concept = @concept
       AND epc.PRPeriod = m.PRPeriod
    WHERE e.Company = @company
      AND e.PayRollType = @payrolltype
      AND e.Person = @person
    GROUP BY
        e.Person,
        sp.LastName1, sp.LastName2, sp.Name1, sp.Name2;
END
GO
