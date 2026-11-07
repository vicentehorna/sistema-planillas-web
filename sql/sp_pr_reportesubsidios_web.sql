/*
    Reporte de Subsidios (hm_ultra) — matriz meses x conceptos afectos AFP.

    Filas: 12 periodos ACTUAL-12 .. ACTUAL-1.
    Columnas: DISTINCT conceptos del query I+flagafectoAFP+FIN_DE_MES+importe>0
              del trabajador, restringido a esos mismos 12 meses (dinámicas, no fijas).
    Result sets:
      1) cabecera (person, personname)
      2) columnas (col_idx, concept, description, formulacode)
      3) celdas (month_idx, prperiod, month_lbl, concept, importe)
      4) totales por concepto (concept, subtotal)
      5) total_ingresos, meses hábiles (desde ingreso), promedio = total/meses

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

    /*
        Columnas = query de referencia del cliente, acotado a los 12 meses
        del trabajador filtrado (#meses = ACTUAL-12 .. ACTUAL-1):
          I + flagafectoAFP='Y', FIN_DE_MES, importe > 0.
        El resultado DISTINCT Description/Concept son las columnas dinámicas.
    */
    IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;
    CREATE TABLE #cols (
        col_idx     int NOT NULL PRIMARY KEY,
        Concept     varchar(20) NOT NULL,
        Description varchar(200) NOT NULL,
        FormulaCode varchar(50) NULL
    );

    INSERT INTO #cols (col_idx, Concept, Description, FormulaCode)
    SELECT
        ROW_NUMBER() OVER (ORDER BY x.Description, x.Concept) AS col_idx,
        x.Concept,
        x.Description,
        x.FormulaCode
    FROM (
        SELECT DISTINCT
            c.Concept,
            LTRIM(RTRIM(c.Description)) AS Description,
            LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) AS FormulaCode
        FROM dbo.PR_EmployeePayRollConcept epc (NOLOCK)
        INNER JOIN dbo.PR_Concept c (NOLOCK)
            ON c.Concept = epc.Concept
        INNER JOIN dbo.PR_ConceptType ct (NOLOCK)
            ON ct.ConceptType = c.ConceptType
           AND LTRIM(RTRIM(ct.ShortName)) = 'I'
           AND UPPER(LTRIM(RTRIM(ISNULL(c.flagafectoAFP, 'N')))) = 'Y'
        WHERE epc.Person = @person
          AND epc.Company = @company
          AND epc.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM dbo.PR_ProcessType pt (NOLOCK)
                WHERE pt.ShortName = 'FIN_DE_MES'
                  AND pt.ProcessType = epc.ProcessType
            )
          AND ISNULL(epc.ConceptValueLo, epc.ConceptValue) > 0
          AND epc.PRPeriod IN (SELECT m.PRPeriod FROM #meses m)
    ) x;

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

    DECLARE @total_ingresos decimal(19, 4) = 0;
    SELECT
        @total_ingresos = CAST(ISNULL(SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue)), 0) AS decimal(19, 4))
    FROM #cols col
    INNER JOIN dbo.PR_EmployeePayRollConcept epc (NOLOCK)
        ON epc.Company = @company
       AND epc.PayRollType = @payrolltype
       AND epc.Person = @person
       AND epc.ProcessType = @process_finmes
       AND epc.Concept = col.Concept
       AND epc.PRPeriod IN (SELECT PRPeriod FROM #meses);

    /* Meses hábiles: periodos del rango con LEFT(PRPeriod,6) >= ingreso/reingreso (yyyymm). */
    DECLARE @fechaingreso datetime = NULL;
    DECLARE @hire_yyyymm char(6) = NULL;
    DECLARE @meses int = 0;
    DECLARE @promedio decimal(19, 4) = 0;

    SELECT TOP 1 @fechaingreso = ISNULL(e.ReEntryDate, e.EntryDate)
    FROM dbo.PR_Employee e (NOLOCK)
    WHERE e.Company = @company
      AND e.PayRollType = @payrolltype
      AND e.Person = @person;

    IF @fechaingreso IS NOT NULL
        SET @hire_yyyymm = LEFT(CONVERT(varchar(8), CONVERT(date, @fechaingreso), 112), 6);

    SELECT @meses = COUNT(*)
    FROM #meses m
    WHERE @hire_yyyymm IS NULL
       OR LEFT(m.PRPeriod, 6) >= @hire_yyyymm;

    IF @meses > 0
        SET @promedio = @total_ingresos / @meses;

    SELECT
        @total_ingresos AS total_ingresos,
        CAST(@meses AS decimal(19, 4)) AS meses,
        @promedio AS promedio;
END
GO
