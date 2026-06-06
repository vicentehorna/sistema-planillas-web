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

        SET @faltas = 0;
        SET @inicio = @fecha;
        WHILE @inicio < @date
        BEGIN
            SET @faltas = @faltas + CASE
                WHEN ISNULL((
                    SELECT COUNT(*)
                    FROM PR_EmployeeMedicalRest
                        INNER JOIN PR_MedicalRestType
                            ON PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
                           AND PR_MedicalRestType.PDT = '07'
                    WHERE PR_EmployeeMedicalRest.Person = @documentnumber
                      AND PR_EmployeeMedicalRest.Company = @company
                      AND @inicio BETWEEN PR_EmployeeMedicalRest.DateBegin AND PR_EmployeeMedicalRest.DateEnd
                ), 0) > 0 THEN 1
                ELSE 0
            END;
            SET @inicio = DATEADD(DD, 1, @inicio);
        END;
        UPDATE xx_saldovacaciones SET faltas = @faltas WHERE person = @documentnumber;

        SET @licencias = 0;
        SET @inicio = @fecha;
        WHILE @inicio <= @date
        BEGIN
            SET @licencias = @licencias + CASE
                WHEN ISNULL((
                    SELECT COUNT(*)
                    FROM PR_EmployeeMedicalRest
                        INNER JOIN PR_MedicalRestType
                            ON PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
                           AND PR_MedicalRestType.PDT = '05'
                    WHERE PR_EmployeeMedicalRest.Person = @documentnumber
                      AND PR_EmployeeMedicalRest.Company = @company
                      AND @inicio BETWEEN PR_EmployeeMedicalRest.DateBegin AND PR_EmployeeMedicalRest.DateEnd
                ), 0) > 0 THEN 1
                ELSE 0
            END;
            SET @inicio = DATEADD(DD, 1, @inicio);
        END;
        UPDATE xx_saldovacaciones SET licencias = @licencias WHERE person = @documentnumber;

        SET @descansos = 0;
        SET @inicio = @inicioProvision;
        WHILE @inicio < @finProvision
        BEGIN
            SET @descansos = @descansos + CASE
                WHEN ISNULL((
                    SELECT COUNT(*)
                    FROM PR_EmployeeMedicalRest
                        INNER JOIN PR_MedicalRestType
                            ON PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
                           AND PR_MedicalRestType.PDT = '20'
                    WHERE PR_EmployeeMedicalRest.Person = @documentnumber
                      AND PR_EmployeeMedicalRest.Company = @company
                      AND @inicio BETWEEN PR_EmployeeMedicalRest.DateBegin AND PR_EmployeeMedicalRest.DateEnd
                ), 0) > 0 THEN 1
                ELSE 0
            END;
            SET @inicio = DATEADD(DD, 1, @inicio);
        END;
        UPDATE xx_saldovacaciones
        SET descansos = ISNULL(descansos, 0) + @descansos
        WHERE person = @documentnumber;

        FETCH NEXT FROM Vacaciones
            INTO @documentnumber, @name, @fecha, @actualyear, @consumo, @inicioProvision, @finProvision;
    END;

    CLOSE Vacaciones;
    DEALLOCATE Vacaciones;

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
        xx_saldovacaciones.faltas,
        xx_saldovacaciones.licencias,
        0 AS descansos
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
