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

    Resultado final: una fila por trabajador con columnas fijas + concept01..concept65.

    Ejemplo:
      EXEC sp_pr_reporteplamevertical_web
           @cia = 'BGT',
           @payrolltype = 'LIMABGT 000000000005',
           @process = 'LIMABGT 000000000001',
           @period = '202604',
           @person = '0',
           @salarybank = '';
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
    @fecha_ingreso_hasta  VARCHAR(10) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SET @fecha_ingreso_all = UPPER(LTRIM(RTRIM(ISNULL(@fecha_ingreso_all, 'Y'))));
    IF @fecha_ingreso_all NOT IN ('Y', 'N') SET @fecha_ingreso_all = 'Y';
    SET @fecha_ingreso_desde = LTRIM(RTRIM(ISNULL(@fecha_ingreso_desde, '')));
    SET @fecha_ingreso_hasta = LTRIM(RTRIM(ISNULL(@fecha_ingreso_hasta, '')));

    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;
    IF @fecha_ingreso_desde <> ''
        SET @fd = TRY_CONVERT(DATE, @fecha_ingreso_desde, 23);
    IF @fecha_ingreso_hasta <> ''
        SET @fh = TRY_CONVERT(DATE, @fecha_ingreso_hasta, 23);

    DECLARE @personid     VARCHAR(20);
    DECLARE @name         VARCHAR(255);
    DECLARE @conceptname  VARCHAR(255);
    DECLARE @columna      VARCHAR(50);
    DECLARE @currency     CHAR(2);
    DECLARE @grupo        CHAR(1);
    DECLARE @conceptvalue NUMERIC(19, 4);
    DECLARE @orden        INT;
    DECLARE @k            INT;
    DECLARE @col          CHAR(20);
    DECLARE @query1       VARCHAR(255);
    DECLARE @concepto     VARCHAR(100);

    SET @currency = 'LO';
    SET @grupo = 'N';

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

    IF @grupo = 'N'
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
    END
    ELSE
    BEGIN
        SELECT
            person,
            name,
            MAX(entrydate),
            MAX(ceasedate),
            (SELECT Description FROM PR_Position WHERE Position = xx_reporteplanilla.position) AS position,
            MAX(afp),
            (SELECT Description FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS ccname,
            (SELECT CCCode FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS costcenter,
            '' AS unidad,
            '' AS tipopago,
            '' AS profile,
            0 AS horas,
            '' AS banco,
            '' AS numcuenta,
            SUM(concept01), SUM(concept02), SUM(concept03), SUM(concept04), SUM(concept05), SUM(concept06), SUM(concept07), SUM(concept08), SUM(concept09), SUM(concept10),
            SUM(concept11), SUM(concept12), SUM(concept13), SUM(concept14), SUM(concept15), SUM(concept16), SUM(concept17), SUM(concept18), SUM(concept19), SUM(concept20),
            SUM(concept21), SUM(concept22), SUM(concept23), SUM(concept24), SUM(concept25), SUM(concept26), SUM(concept27), SUM(concept28), SUM(concept29), SUM(concept30),
            SUM(concept31), SUM(concept32), SUM(concept33), SUM(concept34), SUM(concept35), SUM(concept36), SUM(concept37), SUM(concept38), SUM(concept39), SUM(concept40),
            SUM(concept41), SUM(concept42), SUM(concept43), SUM(concept44), SUM(concept45), SUM(concept46), SUM(concept47), SUM(concept48), SUM(concept49), SUM(concept50),
            SUM(concept51), SUM(concept52), SUM(concept53), SUM(concept54), SUM(concept55), SUM(concept56), SUM(concept57), SUM(concept58), SUM(concept59), SUM(concept60),
            SUM(concept61), SUM(concept62), SUM(concept63), SUM(concept64), SUM(concept65)
        FROM xx_reporteplanilla
        GROUP BY person, name, xx_reporteplanilla.position, xx_reporteplanilla.costcenter
        ORDER BY name;
    END;

    DROP TABLE #Temporal;
END
GO
