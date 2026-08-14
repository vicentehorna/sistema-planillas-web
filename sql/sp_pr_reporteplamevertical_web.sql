/*
    Reporte planilla vertical (PLAME) — conceptos en columnas dinámicas.
    Usado por: POST /reporte_planilla_vertical (reporte_planilla_vertical.html).

    Basado en sp_pr_reporteplamevertical legacy (PowerBuilder).

    Tablas de trabajo (deben existir en la BD):
      xx_plamevertical2  — detalle persona × concepto
      xx_reporteplanilla — matriz persona × concept01..concept65

    Parámetros:
      @cia         — compañía
      @payrolltype — tipo de planilla
      @process     — tipo de proceso
      @period      — periodo (YYYYMM o YYYYMMDD; filtra por LEFT 6)
      @person      — código persona; '0' = todos
      @salarybank  — banco haberes; '' = todos
      @fecha_ingreso_all   — Y = todas las fechas, N = filtrar por rango
      @fecha_ingreso_desde — YYYY-MM-DD (fecha efectiva ISNULL(ReEntryDate, EntryDate))
      @fecha_ingreso_hasta — YYYY-MM-DD
      @repunit     — unidad (ReplicationUnit); '0' = todas
      @agrupar_cc  — Y = agrupar por centro de costo (Cod.Costo, C.Costo, Cantidad + SUM conceptos)
                     N = detalle por trabajador (default; transparente para clientes sin la opción)

    Resultado final:
      @agrupar_cc='N': una fila por trabajador con columnas fijas + concept01..concept65
      @agrupar_cc='Y': una fila por costcenter con Cod.Costo, C.Costo, Cantidad + SUM concept01..65

    Ejemplo:
      EXEC sp_pr_reporteplamevertical_web
           @cia = 'BGT',
           @payrolltype = 'LIMABGT 000000000005',
           @process = 'LIMABGT 000000000001',
           @period = '202604',
           @person = '0',
           @salarybank = '',
           @agrupar_cc = 'N';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplamevertical_web]
    @cia         CHAR(4),
    @payrolltype VARCHAR(20),
    @process     VARCHAR(20),
    @period      VARCHAR(8),
    @person      VARCHAR(20),
    @salarybank  VARCHAR(20),
    @fecha_ingreso_all    CHAR(1)     = 'Y',
    @fecha_ingreso_desde  VARCHAR(10) = '',
    @fecha_ingreso_hasta  VARCHAR(10) = '',
    @repunit              VARCHAR(20) = '0',
    @agrupar_cc           CHAR(1)     = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    SET @fecha_ingreso_all = UPPER(LTRIM(RTRIM(ISNULL(@fecha_ingreso_all, 'Y'))));
    IF @fecha_ingreso_all NOT IN ('Y', 'N') SET @fecha_ingreso_all = 'Y';
    SET @fecha_ingreso_desde = LTRIM(RTRIM(ISNULL(@fecha_ingreso_desde, '')));
    SET @fecha_ingreso_hasta = LTRIM(RTRIM(ISNULL(@fecha_ingreso_hasta, '')));
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';
    SET @agrupar_cc = UPPER(LTRIM(RTRIM(ISNULL(@agrupar_cc, 'N'))));
    IF @agrupar_cc NOT IN ('Y', 'N') SET @agrupar_cc = 'N';

    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;
    IF @fecha_ingreso_desde <> '' AND ISDATE(@fecha_ingreso_desde) = 1
        SET @fd = CONVERT(DATE, @fecha_ingreso_desde, 120);
    IF @fecha_ingreso_hasta <> '' AND ISDATE(@fecha_ingreso_hasta) = 1
        SET @fh = CONVERT(DATE, @fecha_ingreso_hasta, 120);

    DECLARE @personid     VARCHAR(20);
    DECLARE @name         VARCHAR(255);
    DECLARE @conceptname  VARCHAR(255);
    DECLARE @columna      VARCHAR(50);
    DECLARE @currency     CHAR(2);
    DECLARE @conceptvalue NUMERIC(19, 4);
    DECLARE @orden        INT;
    DECLARE @k            INT;
    DECLARE @col          CHAR(20);
    DECLARE @query1       VARCHAR(255);
    DECLARE @concepto     VARCHAR(100);

    SET @currency = 'LO';

    CREATE TABLE [#Temporal] (
        [concepto] VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [columna]  VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    ) ON [PRIMARY];

    DELETE FROM xx_plamevertical2;
    DELETE FROM xx_reporteplanilla;

    INSERT INTO xx_plamevertical2
    SELECT
        PR.description AS processname,
        p.description AS payrolltypename,
        T.description AS concepttypename,
        c.description AS conceptname,
        c.pdt AS pdt,
        epc.person,
        sy_person.name AS name,
        MAX(ISNULL(E.ReEntryDate, E.EntryDate)) AS entrydate,
        MAX(ep.ceasedate) AS ceasedate,
        MAX(ep.position) AS position,
        CASE
            WHEN ISNULL((
                SELECT TOP 1 description
                FROM pr_afp
                WHERE pr_afp.afp = MAX(ep.afp)
            ), '') = '' THEN 'ONP'
            ELSE (
                SELECT TOP 1 description
                FROM pr_afp
                WHERE pr_afp.afp = MAX(ep.afp)
            )
        END,
        MAX(ep.costcenter) AS costcenter,
        CASE
            WHEN @currency = 'LO' THEN SUM(ROUND(EPC.conceptvalue, 2))
            ELSE SUM(ROUND(EPC.ConceptValueEx, 2))
        END AS conceptvalue
    FROM pr_employeepayrollconcept EPC
        INNER JOIN PR_EmployeePayRoll EP
            ON epc.Company = ep.Company
           AND epc.ProcessType = ep.ProcessType
           AND epc.PayRollType = ep.PayRollType
           AND epc.PRPeriod = ep.PRPeriod
           AND epc.Person = ep.Person
        INNER JOIN PR_Employee E
            ON EPC.Company = E.Company
           AND EPC.Person = E.Person
        INNER JOIN pr_payrolltype P ON epc.payrolltype = p.payrolltype
        INNER JOIN pr_concept C ON epc.concept = c.concept
        INNER JOIN pr_concepttype T ON c.concepttype = T.concepttype
        INNER JOIN pr_processtype PR ON epc.processtype = pr.processtype
        INNER JOIN SY_PERSON ON EPC.person = SY_Person.person
    WHERE EPC.company = @cia
      AND LEFT(EPC.prperiod, 6) = LEFT(@period, 6)
      AND ISNULL(c.reporden, 0) <> 0
      AND t.shortname IN ('I', 'D', 'A', 'T', 'G', 'X')
      AND EPC.PayRollType = @payrolltype
      AND EPC.ProcessType = @process
      AND (@salarybank = '' OR E.SalaryBank = @salarybank)
      AND (@person = '0' OR SY_PERSON.person = @person)
      AND (@repunit = '0' OR SY_PERSON.ReplicationUnit = @repunit)
      AND (
            @fecha_ingreso_all = 'Y'
         OR (
                ISNULL(E.ReEntryDate, E.EntryDate) IS NOT NULL
            AND (@fd IS NULL
                 OR CAST(ISNULL(E.ReEntryDate, E.EntryDate) AS DATE) >= @fd)
            AND (@fh IS NULL
                 OR CAST(ISNULL(E.ReEntryDate, E.EntryDate) AS DATE) <= @fh)
            )
      )
      AND epc.Person <> 'T3549'
    GROUP BY
        PR.description,
        p.description,
        T.description,
        c.description,
        c.pdt,
        epc.person,
        sy_person.name
    ORDER BY 7;

    INSERT INTO xx_reporteplanilla (
        person, name, entrydate, ceasedate, position, afp, costcenter,
        concept01, concept02, concept03, concept04, concept05, concept06, concept07, concept08, concept09, concept10,
        concept11, concept12, concept13, concept14, concept15, concept16, concept17, concept18, concept19, concept20,
        concept21, concept22, concept23, concept24, concept25, concept26, concept27, concept28, concept29, concept30,
        concept31, concept32, concept33, concept34, concept35, concept36, concept37, concept38, concept39, concept40,
        concept41, concept42, concept43, concept44, concept45, concept46, concept47, concept48, concept49, concept50,
        concept51, concept52, concept53, concept54, concept55, concept56, concept57, concept58, concept59, concept60,
        concept61, concept62, concept63, concept64, concept65
    )
    SELECT DISTINCT
        person, name, entrydate, ceasedate, position, afp, costcenter,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0
    FROM xx_plamevertical2
    ORDER BY name;

    SET @k = 0;

    DECLARE lista CURSOR FOR
        SELECT DISTINCT conceptname, reporden
        FROM xx_plamevertical2
            INNER JOIN PR_Concept
                ON xx_plamevertical2.conceptname = PR_Concept.Description
               AND PR_Concept.Company = @cia
        ORDER BY reporden, conceptname ASC;

    OPEN lista;
    FETCH NEXT FROM lista INTO @concepto, @orden;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @query1 = '';
        SET @k = @k + 1;
        SET @col = 'concept' + REPLICATE('0', 2 - LEN(CONVERT(CHAR(2), @k))) + CONVERT(CHAR(2), @k);
        INSERT INTO #Temporal VALUES (@concepto, @col);
        FETCH NEXT FROM lista INTO @concepto, @orden;
    END;
    CLOSE lista;
    DEALLOCATE lista;

    DECLARE listareporte CURSOR FOR
        SELECT person, name, conceptname, ISNULL(conceptvalue, 0)
        FROM xx_plamevertical2;

    OPEN listareporte;
    FETCH NEXT FROM listareporte INTO @personid, @name, @conceptname, @conceptvalue;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @query1 = '';
        SELECT @columna = columna FROM #Temporal WHERE concepto = @conceptname;
        SET @query1 = 'UPDATE xx_reporteplanilla SET ' + @columna + ' = ' + CONVERT(VARCHAR(20), @conceptvalue)
                    + ' WHERE person = ' + CHAR(39) + @personid + CHAR(39);
        EXECUTE(@query1);
        FETCH NEXT FROM listareporte INTO @personid, @name, @conceptname, @conceptvalue;
    END;
    CLOSE listareporte;
    DEALLOCATE listareporte;

    IF @agrupar_cc = 'Y'
    BEGIN
        /* Agrupado por C.Costo: misma matriz, SUM de importes + cantidad de trabajadores. */
        SELECT
            ISNULL((
                SELECT CCCode FROM AC_CostCenter
                WHERE CostCenter = r.costcenter
            ), '') AS costcenter,
            ISNULL((
                SELECT Description FROM AC_CostCenter
                WHERE CostCenter = r.costcenter
            ), '') AS ccname,
            COUNT(DISTINCT r.person) AS cantidad,
            SUM(r.concept01), SUM(r.concept02), SUM(r.concept03), SUM(r.concept04), SUM(r.concept05),
            SUM(r.concept06), SUM(r.concept07), SUM(r.concept08), SUM(r.concept09), SUM(r.concept10),
            SUM(r.concept11), SUM(r.concept12), SUM(r.concept13), SUM(r.concept14), SUM(r.concept15),
            SUM(r.concept16), SUM(r.concept17), SUM(r.concept18), SUM(r.concept19), SUM(r.concept20),
            SUM(r.concept21), SUM(r.concept22), SUM(r.concept23), SUM(r.concept24), SUM(r.concept25),
            SUM(r.concept26), SUM(r.concept27), SUM(r.concept28), SUM(r.concept29), SUM(r.concept30),
            SUM(r.concept31), SUM(r.concept32), SUM(r.concept33), SUM(r.concept34), SUM(r.concept35),
            SUM(r.concept36), SUM(r.concept37), SUM(r.concept38), SUM(r.concept39), SUM(r.concept40),
            SUM(r.concept41), SUM(r.concept42), SUM(r.concept43), SUM(r.concept44), SUM(r.concept45),
            SUM(r.concept46), SUM(r.concept47), SUM(r.concept48), SUM(r.concept49), SUM(r.concept50),
            SUM(r.concept51), SUM(r.concept52), SUM(r.concept53), SUM(r.concept54), SUM(r.concept55),
            SUM(r.concept56), SUM(r.concept57), SUM(r.concept58), SUM(r.concept59), SUM(r.concept60),
            SUM(r.concept61), SUM(r.concept62), SUM(r.concept63), SUM(r.concept64), SUM(r.concept65)
        FROM xx_reporteplanilla r
        GROUP BY r.costcenter
        ORDER BY 1, 2;
    END
    ELSE
    BEGIN
        SELECT
            person,
            name,
            entrydate,
            ceasedate,
            (SELECT Description FROM PR_Position WHERE Position = xx_reporteplanilla.position) AS position,
            afp,
            (SELECT Description FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS ccname,
            (SELECT CCCode FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS costcenter,
            (
                SELECT Description
                FROM SY_ReplicationUnit
                    INNER JOIN SY_Person ON SY_ReplicationUnit.ReplicationUnit = SY_Person.ReplicationUnit
                WHERE SY_Person.Person = xx_reporteplanilla.person
            ) AS unidad,
            (
                SELECT CASE WHEN ISNULL(SY_Person.isrecruiter, 'N') = 'Y' THEN 'H' ELSE 'P' END
                FROM sy_person
                WHERE person = xx_reporteplanilla.person
            ) AS tipopago,
            (
                SELECT description
                FROM PR_AccountProfile
                    INNER JOIN PR_Employee
                        ON PR_AccountProfile.AccountProfile = PR_Employee.AccountProfile
                       AND PR_AccountProfile.company = @cia
                       AND PR_Employee.Person = xx_reporteplanilla.person
            ) AS profile,
            (
                SELECT SUM(hourday)
                FROM PR_REGISTERHOUR
                WHERE period = @period
                  AND Company = @cia
                  AND person = xx_reporteplanilla.person
            ) AS horas,
            CASE
                WHEN (
                    SELECT ShortName
                    FROM PR_ProcessType
                    WHERE Company = @cia AND ProcessType = @process
                ) = 'CTS' THEN (
                    SELECT name
                    FROM ERP_Bank
                        INNER JOIN PR_Employee
                            ON ERP_Bank.Bank = PR_Employee.CTSBank
                           AND ERP_Bank.company = @cia
                           AND PR_Employee.Person = xx_reporteplanilla.person
                )
                ELSE (
                    SELECT name
                    FROM ERP_Bank
                        INNER JOIN PR_Employee
                            ON ERP_Bank.Bank = PR_Employee.SalaryBank
                           AND ERP_Bank.company = @cia
                           AND PR_Employee.Person = xx_reporteplanilla.person
                )
            END AS banco,
            CASE
                WHEN (
                    SELECT ShortName
                    FROM PR_ProcessType
                    WHERE Company = @cia AND ProcessType = @process
                ) = 'CTS' THEN (
                    SELECT CTSAccount
                    FROM PR_Employee
                    WHERE PR_Employee.Person = xx_reporteplanilla.person
                      AND PR_Employee.Company = @cia
                )
                ELSE (
                    SELECT salaryaccount
                    FROM PR_Employee
                    WHERE PR_Employee.Person = xx_reporteplanilla.person
                      AND PR_Employee.Company = @cia
                )
            END AS numcuenta,
            concept01, concept02, concept03, concept04, concept05, concept06, concept07, concept08, concept09, concept10,
            concept11, concept12, concept13, concept14, concept15, concept16, concept17, concept18, concept19, concept20,
            concept21, concept22, concept23, concept24, concept25, concept26, concept27, concept28, concept29, concept30,
            concept31, concept32, concept33, concept34, concept35, concept36, concept37, concept38, concept39, concept40,
            concept41, concept42, concept43, concept44, concept45, concept46, concept47, concept48, concept49, concept50,
            concept51, concept52, concept53, concept54, concept55, concept56, concept57, concept58, concept59, concept60,
            concept61, concept62, concept63, concept64, concept65
        FROM xx_reporteplanilla
        ORDER BY 2;
    END;

    DROP TABLE #Temporal;
END
GO
