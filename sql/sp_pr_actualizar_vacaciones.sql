CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_vacaciones]
    @cia    VARCHAR(4),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ingreso DATETIME;
    DECLARE @dias_vac INT;
    DECLARE @vacsincemonths INT, @vacsinceyears INT;
    DECLARE @vactillmonths INT, @vactillyears INT;
    DECLARE @vacsincefinemonths INT, @vacsincefineyears INT;

    SELECT
        @ingreso = ISNULL(e.ReEntryDate, e.EntryDate),
        /* Prioridad: cupo en ficha; si no, DiasVacaciones del tipo de planilla. */
        @dias_vac = ISNULL(
            NULLIF(e.DiasVacaciones, 0),
            ISNULL(pt.DiasVacaciones, 30)
        )
    FROM PR_Employee e
        LEFT JOIN PR_PayRollType pt
            ON pt.PayRollType = e.PayRollType
           AND pt.Company = e.Company
    WHERE e.Person = @person
      AND e.Company = @cia;

    IF @ingreso IS NULL
    BEGIN
        RAISERROR('No se encontró empleado %s / %s', 16, 1, @person, @cia);
        RETURN;
    END;

    IF @dias_vac IS NULL OR @dias_vac <= 0
        SET @dias_vac = 30;

    SELECT
        @vacsincemonths = ISNULL(VacSinceMonths, 0),
        @vacsinceyears = ISNULL(VacSinceYears, 1),
        @vactillmonths = ISNULL(VacTillMonths, 11),
        @vactillyears = ISNULL(VacTillYears, 1),
        @vacsincefinemonths = ISNULL(VacSinceFineMonths, 0),
        @vacsincefineyears = ISNULL(VacSinceFineYears, 3)
    FROM PR_Mapping
    WHERE Company = @cia;

    CREATE TABLE #temporal (
        person  VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        company VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        line    INT
    );

    INSERT INTO #temporal
    SELECT person, company, line
    FROM PR_Vacation
    WHERE EXISTS (
        SELECT 1
        FROM PR_Employee (NOLOCK)
        WHERE Person = PR_Vacation.Person
          AND Company = PR_Vacation.Company
          AND PR_Vacation.ControlYear < YEAR(ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate))
          AND PR_Vacation.Person = @person
          AND PR_Vacation.Company = @cia
    );

    DELETE FROM PR_VacationDetail
    WHERE Person = @person
      AND Company = @cia
      AND EXISTS (
          SELECT 1 FROM #temporal t
          WHERE t.company = PR_VacationDetail.company
            AND t.person = PR_VacationDetail.person
            AND t.line = PR_VacationDetail.line
      );

    DELETE FROM PR_VacationPay
    WHERE Person = @person
      AND Company = @cia
      AND EXISTS (
          SELECT 1 FROM #temporal t
          WHERE t.company = PR_VacationPay.company
            AND t.person = PR_VacationPay.person
            AND t.line = PR_VacationPay.line
      );

    IF OBJECT_ID(N'dbo.PR_VacationProvisionedDays', N'U') IS NOT NULL
    BEGIN
        DELETE FROM PR_VacationProvisionedDays
        WHERE Person = @person
          AND Company = @cia
          AND EXISTS (
              SELECT 1 FROM #temporal t
              WHERE t.company = PR_VacationProvisionedDays.company
                AND t.person = PR_VacationProvisionedDays.person
                AND t.line = PR_VacationProvisionedDays.line
          );
    END

    DELETE FROM PR_Vacation
    WHERE Person = @person
      AND Company = @cia
      AND EXISTS (
          SELECT 1 FROM #temporal t
          WHERE t.company = PR_Vacation.company
            AND t.person = PR_Vacation.person
            AND t.line = PR_Vacation.line
      );

    /* Recalcular fechas con MD de reingreso/ingreso + offsets de PR_Mapping */
    ;WITH base AS (
        SELECT
            v.Person,
            v.Company,
            v.line,
            v.ControlYear,
            CONVERT(
                DATETIME,
                CAST(v.ControlYear AS VARCHAR(4)) + '-'
                + RIGHT('0' + CAST(MONTH(@ingreso) AS VARCHAR(2)), 2) + '-'
                + RIGHT('0' + CAST(DAY(@ingreso) AS VARCHAR(2)), 2)
            ) AS datebeginprovision
        FROM PR_Vacation v
        WHERE v.Person = @person
          AND v.Company = @cia
          AND CAST(v.ControlYear AS INT) >= YEAR(@ingreso)
    ),
    calc AS (
        SELECT
            b.*,
            /* DateBeginRights */
            CASE
                WHEN MONTH(b.datebeginprovision) + @vacsincemonths > 12
                THEN DATEFROMPARTS(
                    YEAR(b.datebeginprovision) + @vacsinceyears + 1,
                    MONTH(b.datebeginprovision) + @vacsincemonths - 12,
                    DAY(b.datebeginprovision)
                )
                ELSE DATEFROMPARTS(
                    YEAR(b.datebeginprovision) + @vacsinceyears,
                    MONTH(b.datebeginprovision) + @vacsincemonths,
                    DAY(b.datebeginprovision)
                )
            END AS datebeginrights,
            /* DateEndRights */
            CASE
                WHEN MONTH(b.datebeginprovision) + @vactillmonths > 12
                THEN DATEFROMPARTS(
                    YEAR(b.datebeginprovision) + @vactillyears + 1,
                    MONTH(b.datebeginprovision) + @vactillmonths - 12,
                    DAY(b.datebeginprovision)
                )
                ELSE DATEFROMPARTS(
                    YEAR(b.datebeginprovision) + @vactillyears,
                    MONTH(b.datebeginprovision) + @vactillmonths,
                    DAY(b.datebeginprovision)
                )
            END AS dateendrights,
            /* DateEndNormal = (prov + fine offsets) - 1 día */
            DATEADD(
                DAY, -1,
                CASE
                    WHEN MONTH(b.datebeginprovision) + @vacsincefinemonths > 12
                    THEN DATEFROMPARTS(
                        YEAR(b.datebeginprovision) + @vacsincefineyears + 1,
                        MONTH(b.datebeginprovision) + @vacsincefinemonths - 12,
                        DAY(b.datebeginprovision)
                    )
                    ELSE DATEFROMPARTS(
                        YEAR(b.datebeginprovision) + @vacsincefineyears,
                        MONTH(b.datebeginprovision) + @vacsincefinemonths,
                        DAY(b.datebeginprovision)
                    )
                END
            ) AS dateendnormal
        FROM base b
    )
    UPDATE v
    SET
        DateBeginProvision = c.datebeginprovision,
        DateBeginRights = c.datebeginrights,
        DateEndRights = c.dateendrights,
        DateEndNormal = c.dateendnormal,
        Days = @dias_vac,
        /* Cupo anual siempre desde ficha/planilla (también si ya hubo goce). */
        AcquiredDays = @dias_vac,
        ConsumedDays = ISNULL((
            SELECT SUM(Days)
            FROM PR_VacationDetail
            WHERE Company = @cia
              AND Person = v.Person
              AND line = v.line
        ), 0),
        PayedDays = ISNULL((
            SELECT SUM(Days)
            FROM PR_VacationPay
            WHERE Company = @cia
              AND Person = v.Person
              AND line = v.line
        ), 0),
        ProvisionedDays = ISNULL((
            SELECT SUM(Days)
            FROM PR_VacationDetail
            WHERE Company = @cia
              AND Person = v.Person
              AND line = v.line
        ), 0),
        XLastDate = GETDATE(),
        XLastUser = ISNULL(NULLIF(SYSTEM_USER, ''), 'REINGRESO')
    FROM PR_Vacation v
        INNER JOIN calc c
            ON v.Person = c.Person
           AND v.Company = c.Company
           AND v.line = c.line;

    DROP TABLE #temporal;
END
GO
