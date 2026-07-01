/*
    Generación / actualización de periodos vacacionales (PR_Vacation).

    Basado en wf_calculate del sistema legacy (PowerBuilder), simplificado:
      - Días anuales desde PR_PayRollType.DiasVacaciones (sin reglas especiales por empresa).
      - No usa f_pr_formula_countconcept ni recalcula AcquiredDays por meses trabajados.
      - Crea periodos faltantes por año de control (ControlYear).
      - Actualiza Days y AcquiredDays en periodos futuros al cambio de tipo de planilla
        cuando DiasVacaciones <> 30 y difieren del valor configurado.

    Parámetros:
      @company     — compañía (obligatorio).
      @payrolltype — tipo de planilla; '0' = todos.
      @personlist  — lista de códigos person separados por coma; vacío = todos según filtros.
      @solo_activos — Y = solo activos sin fecha de cese; N = incluir cesados.
      @xlastuser   — usuario auditoría.

    Retorna un resultset con contadores del proceso.

    Ejemplo:
      EXEC sp_pr_generar_periodos_vacacionales_web
           @company = 'BGT',
           @payrolltype = 'LIMABGT 000000000005',
           @personlist = 'P00001,P00002',
           @solo_activos = 'Y',
           @xlastuser = 'WEB';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_periodos_vacacionales_web]
    @company      VARCHAR(4),
    @payrolltype  VARCHAR(20) = '0',
    @personlist   VARCHAR(MAX) = NULL,
    @solo_activos CHAR(1) = 'Y',
    @xlastuser    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATETIME = GETDATE();
    DECLARE @personas_procesadas INT = 0;
    DECLARE @periodos_creados INT = 0;
    DECLARE @periodos_actualizados INT = 0;

    DECLARE @vacsincemonths INT;
    DECLARE @vacsinceyears INT;
    DECLARE @vactillmonths INT;
    DECLARE @vactillyears INT;
    DECLARE @vacsincefinemonths INT;
    DECLARE @vacsincefineyears INT;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    IF @payrolltype = '' SET @payrolltype = '0';
    SET @personlist = LTRIM(RTRIM(ISNULL(@personlist, '')));
    SET @solo_activos = UPPER(LTRIM(RTRIM(ISNULL(@solo_activos, 'Y'))));
    IF @solo_activos NOT IN ('Y', 'N') SET @solo_activos = 'Y';
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        @vacsincemonths = ISNULL(VacSinceMonths, 0),
        @vacsinceyears = ISNULL(VacSinceYears, 0),
        @vactillmonths = ISNULL(VacTillMonths, 0),
        @vactillyears = ISNULL(VacTillYears, 0),
        @vacsincefinemonths = ISNULL(VacSinceFineMonths, 0),
        @vacsincefineyears = ISNULL(VacSinceFineYears, 0)
    FROM PR_Mapping (NOLOCK)
    WHERE Company = @company;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @vacsincemonths = 0;
        SET @vacsinceyears = 0;
        SET @vactillmonths = 0;
        SET @vactillyears = 0;
        SET @vacsincefinemonths = 0;
        SET @vacsincefineyears = 0;
    END;

    CREATE TABLE #personas_filtro (
        person VARCHAR(20) NOT NULL PRIMARY KEY
    );

    IF @personlist <> ''
    BEGIN
        INSERT INTO #personas_filtro (person)
        SELECT DISTINCT LTRIM(RTRIM(Split.a.value('.', 'VARCHAR(20)')))
        FROM (
            SELECT CAST('<x>' + REPLACE(@personlist, ',', '</x><x>') + '</x>' AS XML) AS x
        ) t
        CROSS APPLY x.nodes('/x') Split(a)
        WHERE LTRIM(RTRIM(Split.a.value('.', 'VARCHAR(20)'))) <> '';
    END;

    CREATE TABLE #empleados (
        person            VARCHAR(20) NOT NULL PRIMARY KEY,
        company           VARCHAR(4) NOT NULL,
        payrolltype       VARCHAR(20) NOT NULL,
        dias_vacaciones   INT NOT NULL,
        entrydate         DATETIME NOT NULL,
        entry_year        INT NOT NULL,
        years_to_generate INT NOT NULL,
        cambio_planilla   DATETIME NOT NULL,
        dias_anteriores   INT NOT NULL,
        replicationunit   VARCHAR(4) NULL,
        max_line          INT NOT NULL
    );

    INSERT INTO #empleados (
        person, company, payrolltype, dias_vacaciones, entrydate,
        entry_year, years_to_generate, cambio_planilla, dias_anteriores,
        replicationunit, max_line
    )
    SELECT
        e.Person,
        e.Company,
        e.PayRollType,
        ISNULL(pt.DiasVacaciones, 30),
        ing.entrydate,
        YEAR(ing.entrydate),
        CASE
            WHEN YEAR(ing.entrydate) = YEAR(@hoy) THEN 1
            ELSE
                YEAR(@hoy) - YEAR(ing.entrydate) + 1
                - CASE
                    WHEN DATEADD(
                             YEAR,
                             DATEDIFF(YEAR, ing.entrydate, @hoy),
                             CONVERT(DATE, ing.entrydate)
                         ) > CONVERT(DATE, @hoy)
                    THEN 1
                    ELSE 0
                  END
        END,
        ISNULL(cambio.cambio_planilla, ing.entrydate),
        ISNULL(anterior.dias_anteriores, ISNULL(pt.DiasVacaciones, 30)),
        LEFT(ISNULL(NULLIF(LTRIM(RTRIM(sp.ReplicationUnit)), ''), @company), 4),
        ISNULL(vmax.max_line, 0)
    FROM PR_Employee e (NOLOCK)
        INNER JOIN SY_Person sp (NOLOCK)
            ON e.Person = sp.Person
        INNER JOIN PR_PayRollType pt (NOLOCK)
            ON e.PayRollType = pt.PayRollType
           AND pt.Company = e.Company
        CROSS APPLY (
            SELECT CONVERT(DATETIME, CONVERT(DATE, ISNULL(e.ReEntryDate, e.EntryDate))) AS entrydate
        ) ing
        OUTER APPLY (
            SELECT MIN(CONVERT(DATETIME, CONVERT(DATE, ISNULL(ep.EntryDate, ep.XLastDate)))) AS cambio_planilla
            FROM PR_EmployeePayRoll ep (NOLOCK)
            WHERE ep.Person = e.Person
              AND ep.Company = e.Company
              AND ep.PayRollType = e.PayRollType
        ) cambio
        OUTER APPLY (
            SELECT TOP 1 ISNULL(pt2.DiasVacaciones, 30) AS dias_anteriores
            FROM PR_EmployeePayRoll ep2 (NOLOCK)
                INNER JOIN PR_PayRollType pt2 (NOLOCK)
                    ON pt2.PayRollType = ep2.PayRollType
                   AND pt2.Company = ep2.Company
            WHERE ep2.Person = e.Person
              AND ep2.Company = e.Company
              AND ep2.PayRollType <> e.PayRollType
            GROUP BY ep2.PayRollType, pt2.DiasVacaciones
            ORDER BY MAX(CONVERT(DATETIME, CONVERT(DATE, ISNULL(ep2.EntryDate, ep2.XLastDate)))) DESC
        ) anterior
        OUTER APPLY (
            SELECT MAX(v.line) AS max_line
            FROM PR_Vacation v (NOLOCK)
            WHERE v.Person = e.Person
              AND v.Company = e.Company
        ) vmax
    WHERE e.Company = @company
      AND (@payrolltype = '0' OR e.PayRollType = @payrolltype)
      AND (
            @personlist = ''
         OR EXISTS (SELECT 1 FROM #personas_filtro pf WHERE pf.person = e.Person)
      )
      AND (
            @solo_activos = 'N'
         OR (e.Status = 'N' AND e.CeaseDate IS NULL)
      )
      AND ing.entrydate IS NOT NULL
      AND (
            CASE
                WHEN YEAR(ing.entrydate) = YEAR(@hoy) THEN 1
                ELSE
                    YEAR(@hoy) - YEAR(ing.entrydate) + 1
                    - CASE
                        WHEN DATEADD(
                                 YEAR,
                                 DATEDIFF(YEAR, ing.entrydate, @hoy),
                                 CONVERT(DATE, ing.entrydate)
                             ) > CONVERT(DATE, @hoy)
                        THEN 1
                        ELSE 0
                      END
            END
          ) >= 0;

    IF NOT EXISTS (SELECT 1 FROM #empleados)
    BEGIN
        SELECT
            0 AS personas_procesadas,
            0 AS periodos_creados,
            0 AS periodos_actualizados,
            'Sin trabajadores para procesar.' AS mensaje;
        RETURN;
    END;

    CREATE TABLE #nums (j INT NOT NULL PRIMARY KEY);
    ;WITH n AS (
        SELECT 0 AS j
        UNION ALL
        SELECT j + 1 FROM n WHERE j < 60
    )
    INSERT INTO #nums (j)
    SELECT j FROM n
    OPTION (MAXRECURSION 100);

    CREATE TABLE #periodos_generar (
        person              VARCHAR(20) NOT NULL,
        company             VARCHAR(4) NOT NULL,
        controlyear         VARCHAR(4) NOT NULL,
        dias                INT NOT NULL,
        datebeginprovision  DATETIME NOT NULL,
        datebeginrights     DATETIME NOT NULL,
        dateendrights       DATETIME NOT NULL,
        dateendnormal       DATETIME NOT NULL,
        replicationunit     VARCHAR(4) NULL,
        line                INT NOT NULL,
        PRIMARY KEY (person, controlyear)
    );

    INSERT INTO #periodos_generar (
        person, company, controlyear, dias, datebeginprovision,
        datebeginrights, dateendrights, dateendnormal, replicationunit, line
    )
    SELECT
        emp.person,
        emp.company,
        CAST(emp.entry_year + n.j AS VARCHAR(4)),
        CASE
            WHEN prov.datebeginprovision >= emp.cambio_planilla THEN emp.dias_vacaciones
            ELSE emp.dias_anteriores
        END,
        prov.datebeginprovision,
        rights.datebeginrights,
        till.dateendrights,
        fine.dateendnormal,
        emp.replicationunit,
        emp.max_line
            + ROW_NUMBER() OVER (
                PARTITION BY emp.person
                ORDER BY emp.entry_year + n.j
              )
    FROM #empleados emp
        INNER JOIN #nums n
            ON n.j <= emp.years_to_generate
        CROSS APPLY (
            SELECT CONVERT(DATETIME,
                CAST(emp.entry_year + n.j AS VARCHAR(4)) + '-'
                + RIGHT('0' + CAST(MONTH(emp.entrydate) AS VARCHAR(2)), 2) + '-'
                + RIGHT('0' + CAST(DAY(emp.entrydate) AS VARCHAR(2)), 2)
            ) AS datebeginprovision
        ) prov
        CROSS APPLY (
            SELECT
                MONTH(prov.datebeginprovision) + @vacsincemonths AS m0,
                YEAR(prov.datebeginprovision) + @vacsinceyears AS y0
        ) r0
        CROSS APPLY (
            SELECT
                CASE WHEN r0.m0 > 12 THEN r0.m0 - 12 ELSE r0.m0 END AS m,
                CASE WHEN r0.m0 > 12 THEN r0.y0 + 1 ELSE r0.y0 END AS y,
                DAY(prov.datebeginprovision) AS d
        ) r1
        CROSS APPLY (
            SELECT CONVERT(DATETIME,
                CAST(r1.y AS VARCHAR(4)) + '-'
                + RIGHT('0' + CAST(r1.m AS VARCHAR(2)), 2) + '-'
                + RIGHT('0' + CAST(r1.d AS VARCHAR(2)), 2)
            ) AS datebeginrights
        ) rights
        CROSS APPLY (
            SELECT
                MONTH(prov.datebeginprovision) + @vactillmonths AS m0,
                YEAR(prov.datebeginprovision) + @vactillyears AS y0
        ) t0
        CROSS APPLY (
            SELECT
                CASE WHEN t0.m0 > 12 THEN t0.m0 - 12 ELSE t0.m0 END AS m,
                CASE WHEN t0.m0 > 12 THEN t0.y0 + 1 ELSE t0.y0 END AS y,
                DAY(prov.datebeginprovision) AS d
        ) t1
        CROSS APPLY (
            SELECT CONVERT(DATETIME,
                CAST(t1.y AS VARCHAR(4)) + '-'
                + RIGHT('0' + CAST(t1.m AS VARCHAR(2)), 2) + '-'
                + RIGHT('0' + CAST(t1.d AS VARCHAR(2)), 2)
            ) AS dateendrights
        ) till
        CROSS APPLY (
            SELECT
                MONTH(prov.datebeginprovision) + @vacsincefinemonths AS m0,
                YEAR(prov.datebeginprovision) + @vacsincefineyears AS y0
        ) f0
        CROSS APPLY (
            SELECT
                CASE WHEN f0.m0 > 12 THEN f0.m0 - 12 ELSE f0.m0 END AS m,
                CASE WHEN f0.m0 > 12 THEN f0.y0 + 1 ELSE f0.y0 END AS y,
                DAY(prov.datebeginprovision) AS d
        ) f1
        CROSS APPLY (
            SELECT DATEADD(DAY, -1, CONVERT(DATETIME,
                CAST(f1.y AS VARCHAR(4)) + '-'
                + RIGHT('0' + CAST(f1.m AS VARCHAR(2)), 2) + '-'
                + RIGHT('0' + CAST(f1.d AS VARCHAR(2)), 2)
            )) AS dateendnormal
        ) fine
    WHERE NOT EXISTS (
        SELECT 1
        FROM PR_Vacation v (NOLOCK)
        WHERE v.Person = emp.person
          AND v.Company = emp.company
          AND v.ControlYear = CAST(emp.entry_year + n.j AS VARCHAR(4))
          AND v.status = 'A'
    );

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO PR_Vacation (
            Person, Company, line, ControlYear, Days, ConsumedDays, PayedDays,
            ProvisionedDays, DateBeginProvision, DateBeginRights, DateEndRights,
            DateEndNormal, ReplicationUnit, XLastUser, XLastDate, status, AcquiredDays
        )
        SELECT
            pg.person,
            pg.company,
            pg.line,
            pg.controlyear,
            pg.dias,
            0,
            0,
            0,
            pg.datebeginprovision,
            pg.datebeginrights,
            pg.dateendrights,
            pg.dateendnormal,
            pg.replicationunit,
            @xlastuser,
            @hoy,
            'A',
            pg.dias
        FROM #periodos_generar pg;

        SET @periodos_creados = @@ROWCOUNT;

        UPDATE v
        SET
            v.Days = emp.dias_vacaciones,
            v.AcquiredDays = emp.dias_vacaciones,
            v.XLastUser = @xlastuser,
            v.XLastDate = @hoy
        FROM PR_Vacation v
            INNER JOIN #empleados emp
                ON v.Person = emp.person
               AND v.Company = emp.company
        WHERE v.status = 'A'
          AND emp.dias_vacaciones <> 30
          AND CONVERT(DATE, v.DateBeginProvision) >= CONVERT(DATE, emp.cambio_planilla)
          AND (
                ISNULL(v.Days, 0) <> emp.dias_vacaciones
             OR ISNULL(v.AcquiredDays, 0) <> emp.dias_vacaciones
          );

        SET @periodos_actualizados = @@ROWCOUNT;
        SET @personas_procesadas = (SELECT COUNT(*) FROM #empleados);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @errmsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@errmsg, 16, 1);
        RETURN;
    END CATCH;

    SELECT
        @personas_procesadas AS personas_procesadas,
        @periodos_creados AS periodos_creados,
        @periodos_actualizados AS periodos_actualizados,
        'Proceso concluido.' AS mensaje;
END
GO
