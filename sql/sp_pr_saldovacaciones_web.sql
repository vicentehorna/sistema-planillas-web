/*
    Saldo de vacaciones por trabajador y año de control.
    Usado por: POST /reporte_saldo_vacaciones (reporte_saldo_vacaciones.html).

    Calcula saldos pendientes (saldo1..saldo5), faltas, licencias y descansos
    a una fecha de corte. Usa tabla de trabajo xx_saldovacaciones y función f_getDias360.

    Parámetros:
      @company, @payrolltype — obligatorios.
      @date — fecha de corte del saldo.
      @person — '0' = todos; otro valor filtra por código person.
      @cesados — T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.

    Nota: actualiza PR_Vacation.consumeddays2 al inicio (lógica heredada del ERP).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_saldovacaciones_web]
    @company      CHAR(4),
    @payrolltype  VARCHAR(20),
    @date         DATETIME,
    @person       VARCHAR(20),
    @cesados      CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @year           NUMERIC(9, 0);
    DECLARE @actualyear     NUMERIC(9, 0);
    DECLARE @consumo        NUMERIC(9, 4);
    DECLARE @faltas         INT;
    DECLARE @licencias      INT;
    DECLARE @descansos      INT;
    DECLARE @documentnumber VARCHAR(20);
    DECLARE @name           VARCHAR(255);
    DECLARE @fecha          VARCHAR(20);
    DECLARE @inicio         DATETIME;
    DECLARE @inicioProvision DATETIME;
    DECLARE @finProvision   DATETIME;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    /* Ajuste de días consumidos considerando vacaciones con inicio posterior a la fecha de corte. */
    UPDATE PR_Vacation
    SET consumeddays2 = consumeddays;

    UPDATE PR_Vacation
    SET consumeddays2 = consumeddays2 - (
            SELECT SUM(Days)
            FROM PR_VacationDetail
            WHERE Person = PR_Vacation.Person
              AND Line = PR_Vacation.Line
              AND Company = PR_Vacation.Company
              AND DateBegin > @date
        )
    WHERE EXISTS (
            SELECT 1
            FROM PR_VacationDetail
            WHERE Person = PR_Vacation.Person
              AND Line = PR_Vacation.Line
              AND Company = PR_Vacation.Company
              AND DateBegin > @date
        );

    SET @descansos = 0;
    DELETE FROM xx_saldovacaciones;

    SET @year = YEAR(@date) + 1;

    INSERT INTO xx_saldovacaciones (company, person, name, entrydate, payrolltype)
    SELECT DISTINCT
        compania,
        DocumentNumber,
        Name,
        CONVERT(VARCHAR(8), entrydate, 112) AS fechaingreso,
        PayRollType
    FROM (
        SELECT
            @company AS compania,
            SY_Person.Person AS DocumentNumber,
            SY_Person.Name,
            ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate) AS entrydate,
            ControlYear,
            CASE
                WHEN CONVERT(VARCHAR(8), DateBeginProvision, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                    CASE
                        WHEN CONVERT(VARCHAR(8), DateBeginRights, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                            ABS(consumeddays2 - acquireddays)
                        ELSE
                            ROUND((dbo.f_getDias360(DateBeginProvision, @date) * 2.5) / 30, 2) - consumeddays2
                    END
                ELSE 0
            END AS porconsumir,
            PR_Employee.PayRollType AS PayRollType
        FROM PR_Vacation
            INNER JOIN PR_Employee
                ON PR_Vacation.Person = PR_Employee.Person
               AND PR_Employee.Status = 'N'
            INNER JOIN SY_Person
                ON PR_Employee.Person = SY_Person.Person
            INNER JOIN SY_Company
                ON PR_Vacation.Company = SY_Company.Company
        WHERE ControlYear < YEAR(@date) + 1
          AND ControlYear >= YEAR(ISNULL(ReEntryDate, EntryDate))
          AND PR_Employee.PayRollType = @payrolltype
          AND (@person = '0' OR PR_Vacation.Person = @person)
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND PR_Employee.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND PR_Employee.CeaseDate IS NULL)
          )
          AND PR_Vacation.Company = @company
          AND ABS(consumeddays2 - acquireddays) > 0
    ) X
    ORDER BY 1, 3;

    DECLARE Vacaciones CURSOR FOR
    SELECT
        DocumentNumber,
        Name,
        CONVERT(VARCHAR(8), entrydate, 112) AS fechaingreso,
        controlyear,
        porconsumir,
        X.inicioProvision,
        X.finProvision
    FROM (
        SELECT
            SY_Company.Description AS compania,
            SY_Person.Person AS DocumentNumber,
            SY_Person.Name,
            ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate) AS entrydate,
            ControlYear,
            CASE
                WHEN CONVERT(VARCHAR(8), DateBeginProvision, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                    CASE
                        WHEN CONVERT(VARCHAR(8), DateBeginRights, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                            ABS(consumeddays2 - acquireddays)
                        ELSE
                            ROUND((dbo.f_getDias360(DateBeginProvision, @date) * 2.5) / 30, 2) - consumeddays2
                    END
                ELSE 0
            END AS porconsumir,
            PR_Vacation.DateBeginProvision AS inicioProvision,
            PR_Vacation.DateBeginRights AS finProvision
        FROM PR_Vacation
            INNER JOIN PR_Employee
                ON PR_Vacation.Person = PR_Employee.Person
               AND PR_Employee.Status = 'N'
            INNER JOIN SY_Person
                ON PR_Employee.Person = SY_Person.Person
            INNER JOIN SY_Company
                ON PR_Vacation.Company = SY_Company.Company
        WHERE ControlYear < YEAR(@date) + 1
          AND ControlYear >= YEAR(ISNULL(ReEntryDate, EntryDate))
          AND PR_Employee.PayRollType = @payrolltype
          AND PR_Vacation.Company = @company
          AND (@person = '0' OR PR_Vacation.Person = @person)
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND PR_Employee.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND PR_Employee.CeaseDate IS NULL)
          )
          AND ABS(consumeddays2 - acquireddays) > 0
    ) X
    ORDER BY 2;

    OPEN Vacaciones;
    FETCH NEXT FROM Vacaciones
        INTO @documentnumber, @name, @fecha, @actualyear, @consumo, @inicioProvision, @finProvision;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @actualyear = @year - 5
            UPDATE xx_saldovacaciones SET saldo1 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 4
            UPDATE xx_saldovacaciones SET saldo2 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 3
            UPDATE xx_saldovacaciones SET saldo3 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 2
            UPDATE xx_saldovacaciones SET saldo4 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 1
            UPDATE xx_saldovacaciones SET saldo5 = @consumo WHERE person = @documentnumber;

        /* Descansos (PDT 20): acumula por periodo de provisión de cada año de control. */
        SET @descansos = 0;
        IF @inicioProvision IS NOT NULL AND @finProvision IS NOT NULL AND @inicioProvision < @finProvision
        BEGIN
            SELECT @descansos = COUNT(*)
            FROM (
                SELECT TOP (DATEDIFF(DAY, @inicioProvision, @finProvision))
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
                FROM sys.all_objects a
                    CROSS JOIN sys.all_objects b
            ) tally
            CROSS APPLY (SELECT DATEADD(DAY, tally.n, @inicioProvision) AS d) cal
            WHERE EXISTS (
                SELECT 1
                FROM PR_EmployeeMedicalRest emr
                    INNER JOIN PR_MedicalRestType mrt
                        ON emr.MedicalRestType = mrt.MedicalRestType
                       AND mrt.PDT = '20'
                WHERE emr.Person = @documentnumber
                  AND emr.Company = @company
                  AND cal.d BETWEEN emr.DateBegin AND emr.DateEnd
            );
        END;
        UPDATE xx_saldovacaciones
        SET descansos = ISNULL(descansos, 0) + @descansos
        WHERE person = @documentnumber;

        FETCH NEXT FROM Vacaciones
            INTO @documentnumber, @name, @fecha, @actualyear, @consumo, @inicioProvision, @finProvision;
    END;

    CLOSE Vacaciones;
    DEALLOCATE Vacaciones;

    /* Faltas y licencias: una sola vez por trabajador (no por año de control). */
    UPDATE sv
    SET
        faltas = calc.faltas,
        licencias = calc.licencias
    FROM xx_saldovacaciones sv
    CROSS APPLY (
        SELECT CONVERT(DATETIME, sv.entrydate, 112) AS inicio_emp
    ) ing
    CROSS APPLY (
        SELECT
            (
                SELECT COUNT(*)
                FROM (
                    SELECT TOP (
                        CASE
                            WHEN DATEDIFF(DAY, ing.inicio_emp, @date) > 0
                                THEN DATEDIFF(DAY, ing.inicio_emp, @date)
                            ELSE 0
                        END
                    )
                        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
                    FROM sys.all_objects a
                        CROSS JOIN sys.all_objects b
                ) tally
                CROSS APPLY (SELECT DATEADD(DAY, tally.n, ing.inicio_emp) AS d) cal
                WHERE EXISTS (
                    SELECT 1
                    FROM PR_EmployeeMedicalRest emr
                        INNER JOIN PR_MedicalRestType mrt
                            ON emr.MedicalRestType = mrt.MedicalRestType
                           AND mrt.PDT = '07'
                    WHERE emr.Person = sv.person
                      AND emr.Company = sv.company
                      AND cal.d BETWEEN emr.DateBegin AND emr.DateEnd
                )
            ) AS faltas,
            (
                SELECT COUNT(*)
                FROM (
                    SELECT TOP (
                        CASE
                            WHEN DATEDIFF(DAY, ing.inicio_emp, @date) >= 0
                                THEN DATEDIFF(DAY, ing.inicio_emp, @date) + 1
                            ELSE 0
                        END
                    )
                        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
                    FROM sys.all_objects a
                        CROSS JOIN sys.all_objects b
                ) tally
                CROSS APPLY (SELECT DATEADD(DAY, tally.n, ing.inicio_emp) AS d) cal
                WHERE EXISTS (
                    SELECT 1
                    FROM PR_EmployeeMedicalRest emr
                        INNER JOIN PR_MedicalRestType mrt
                            ON emr.MedicalRestType = mrt.MedicalRestType
                           AND mrt.PDT = '05'
                    WHERE emr.Person = sv.person
                      AND emr.Company = sv.company
                      AND cal.d BETWEEN emr.DateBegin AND emr.DateEnd
                )
            ) AS licencias
    ) calc;

    SELECT
        PR_PayRollType.ShortName AS tipoplanillas,
        xx_saldovacaciones.person AS person,
        xx_saldovacaciones.name,
        SY_ReplicationUnit.Description AS description,
        CONVERT(DATETIME, ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate)) AS entrydate,
        PR_Employee.CeaseDate AS ceasedate,
        ISNULL(saldo1, 0) AS saldo1,
        ISNULL(saldo2, 0) AS saldo2,
        ISNULL(saldo3, 0) AS saldo3,
        ISNULL(saldo4, 0) AS saldo4,
        ISNULL(saldo5, 0) AS saldo5,
        ISNULL(xx_saldovacaciones.faltas, 0) AS faltas,
        ISNULL(xx_saldovacaciones.licencias, 0) AS licencias,
        ISNULL(xx_saldovacaciones.descansos, 0) AS descansos,
        ROUND(
            ISNULL(saldo1, 0) + ISNULL(saldo2, 0) + ISNULL(saldo3, 0) + ISNULL(saldo4, 0) + ISNULL(saldo5, 0)
            - ROUND(ISNULL(xx_saldovacaciones.faltas, 0) * 2.5 / 30.0, 2)
            - ROUND(ISNULL(xx_saldovacaciones.licencias, 0) * 2.5 / 30.0, 2)
            - CASE
                WHEN ISNULL(xx_saldovacaciones.descansos, 0) >= 60
                THEN ROUND(ISNULL(xx_saldovacaciones.descansos, 0) * 2.5 / 30.0, 2)
                ELSE 0
              END,
            2
        ) AS saldo
    FROM xx_saldovacaciones
        INNER JOIN PR_PayRollType
            ON xx_saldovacaciones.payrolltype = PR_PayRollType.PayRollType
        INNER JOIN PR_Employee
            ON xx_saldovacaciones.person = PR_Employee.Person
           AND xx_saldovacaciones.company = PR_Employee.Company
        INNER JOIN SY_Person
            ON xx_saldovacaciones.person = SY_Person.Person
        LEFT JOIN SY_ReplicationUnit
            ON SY_Person.ReplicationUnit = SY_ReplicationUnit.ReplicationUnit
    ORDER BY xx_saldovacaciones.name;
END
GO
