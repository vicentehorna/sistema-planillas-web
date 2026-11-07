/*
    Reporte de Subsidios (hm_ultra) — matriz meses x conceptos afectos AFP.

    Filas: 12 periodos ACTUAL-12 .. ACTUAL-1.
    Columnas: conceptos tipo Ingreso (ConceptType.ShortName = 'I') con flagafectoAFP = 'Y'
              que el trabajador tuvo con importe > 0 en proceso FIN_DE_MES dentro del rango.
    Result sets:
      1) cabecera (person, personname)
      2) columnas (col_idx, concept, description, formulacode)
      3) celdas (month_idx, prperiod, month_lbl, concept, importe)
      4) totales por concepto (concept, subtotal) + total_ingresos

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

    /* Proceso MENSUAL / FIN_DE_MES para montos del reporte (query de referencia). */
    DECLARE @process_finmes varchar(20) = NULL;
    SELECT TOP 1 @process_finmes = ProcessType
    FROM dbo.PR_ProcessType (NOLOCK)
    WHERE Company = @company
      AND UPPER(LTRIM(RTRIM(ISNULL(ShortName, '')))) = 'FIN_DE_MES'
    ORDER BY ProcessType;

    IF @process_finmes IS NULL
        SET @process_finmes = @processtype;

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

    IF OBJECT_ID('tempdb..#meses') IS NOT NULL DROP TABLE #meses;
    CREATE TABLE #meses (
        idx      int NOT NULL PRIMARY KEY,
        PRPeriod varchar(20) NOT NULL,
        lbl      varchar(40) NOT NULL
    );

    DECLARE @i int = 1;
    DECLARE @po int;
    DECLARE @pp varchar(20);
    DECLARE @mm char(2);
    DECLARE @yy char(4);
    DECLARE @mesnom varchar(10);

    WHILE @i <= 12
    BEGIN
        SET @po = @ord - (13 - @i);
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
            WHEN '01' THEN 'Enero' WHEN '02' THEN 'Febrero' WHEN '03' THEN 'Marzo'
            WHEN '04' THEN 'Abril' WHEN '05' THEN 'Mayo' WHEN '06' THEN 'Junio'
            WHEN '07' THEN 'Julio' WHEN '08' THEN 'Agosto' WHEN '09' THEN 'Setiembre'
            WHEN '10' THEN 'Octubre' WHEN '11' THEN 'Noviembre' WHEN '12' THEN 'Diciembre'
            ELSE @mm END;

        INSERT INTO #meses (idx, PRPeriod, lbl)
        VALUES (@i, @pp, @mesnom + ' ' + @yy);

        SET @i = @i + 1;
    END;

    /* Columnas: conceptos I + flagafectoAFP con importe > 0 en el rango / FIN_DE_MES */
    IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;
    CREATE TABLE #cols (
        col_idx     int NOT NULL IDENTITY(1, 1) PRIMARY KEY,
        Concept     varchar(20) NOT NULL,
        Description varchar(200) NOT NULL,
        FormulaCode varchar(50) NULL
    );

    INSERT INTO #cols (Concept, Description, FormulaCode)
    SELECT
        c.Concept,
        MAX(LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(c.PrintText)), ''), c.Description)))) AS Description,
        MAX(LTRIM(RTRIM(ISNULL(c.FormulaCode, '')))) AS FormulaCode
    FROM dbo.PR_EmployeePayRollConcept epc (NOLOCK)
    INNER JOIN dbo.PR_Concept c (NOLOCK)
        ON c.Concept = epc.Concept
       AND c.Company = epc.Company
    INNER JOIN dbo.PR_ConceptType ct (NOLOCK)
        ON ct.ConceptType = c.ConceptType
    INNER JOIN #meses m
        ON m.PRPeriod = epc.PRPeriod
    WHERE epc.Company = @company
      AND epc.PayRollType = @payrolltype
      AND epc.Person = @person
      AND epc.ProcessType = @process_finmes
      AND UPPER(LTRIM(RTRIM(ISNULL(ct.ShortName, '')))) = 'I'
      AND UPPER(LTRIM(RTRIM(ISNULL(c.flagafectoAFP, 'N')))) = 'Y'
      AND ISNULL(epc.ConceptValueLo, epc.ConceptValue) > 0
    GROUP BY c.Concept
    ORDER BY MAX(LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(c.PrintText)), ''), c.Description)))), c.Concept;

    /* RS1: trabajador */
    SELECT
        LTRIM(RTRIM(e.Person)) AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS personname
    FROM dbo.PR_Employee e (NOLOCK)
    INNER JOIN dbo.SY_Person sp (NOLOCK)
        ON sp.Person = e.Person
    WHERE e.Company = @company
      AND e.PayRollType = @payrolltype
      AND e.Person = @person;

    /* RS2: columnas */
    SELECT col_idx, Concept AS concept, Description AS description, FormulaCode AS formulacode
    FROM #cols
    ORDER BY col_idx;

    /* RS3: celdas mes x concepto (incluye meses sin importe = 0) */
    SELECT
        m.idx AS month_idx,
        m.PRPeriod AS prperiod,
        m.lbl AS month_lbl,
        col.col_idx,
        col.Concept AS concept,
        col.Description AS description,
        CAST(ISNULL(SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue)), 0) AS decimal(19, 4)) AS importe
    FROM #meses m
    CROSS JOIN #cols col
    LEFT JOIN dbo.PR_EmployeePayRollConcept epc (NOLOCK)
        ON epc.Company = @company
       AND epc.PayRollType = @payrolltype
       AND epc.Person = @person
       AND epc.ProcessType = @process_finmes
       AND epc.PRPeriod = m.PRPeriod
       AND epc.Concept = col.Concept
    GROUP BY
        m.idx, m.PRPeriod, m.lbl,
        col.col_idx, col.Concept, col.Description
    ORDER BY m.idx, col.col_idx;

    /* RS4: subtotales por concepto + total ingresos */
    SELECT
        col.col_idx,
        col.Concept AS concept,
        col.Description AS description,
        CAST(ISNULL(SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue)), 0) AS decimal(19, 4)) AS subtotal
    FROM #cols col
    LEFT JOIN dbo.PR_EmployeePayRollConcept epc (NOLOCK)
        ON epc.Company = @company
       AND epc.PayRollType = @payrolltype
       AND epc.Person = @person
       AND epc.ProcessType = @process_finmes
       AND epc.Concept = col.Concept
       AND epc.PRPeriod IN (SELECT PRPeriod FROM #meses)
    GROUP BY col.col_idx, col.Concept, col.Description
    ORDER BY col.col_idx;

    SELECT
        CAST(ISNULL(SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue)), 0) AS decimal(19, 4)) AS total_ingresos
    FROM #cols col
    INNER JOIN dbo.PR_EmployeePayRollConcept epc (NOLOCK)
        ON epc.Company = @company
       AND epc.PayRollType = @payrolltype
       AND epc.Person = @person
       AND epc.ProcessType = @process_finmes
       AND epc.Concept = col.Concept
       AND epc.PRPeriod IN (SELECT PRPeriod FROM #meses);
END
GO
