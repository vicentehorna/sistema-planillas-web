/*
    Saldo de vacaciones por trabajador y año de control.
    Usado por: POST /reporte_saldo_vacaciones (reporte_saldo_vacaciones.html).

    Requiere: dbo.f_count_medical_rest_days_web, xx_saldovacaciones, f_getDias360.
    Nota: consumeddays2 se calcula en consulta (no actualiza PR_Vacation).
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

    DECLARE @year NUMERIC(9, 0);

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    SET @date = CAST(@date AS DATE);
    SET @year = YEAR(@date) + 1;

    IF OBJECT_ID('tempdb..#VacSaldo') IS NOT NULL DROP TABLE #VacSaldo;

    SELECT
        e.Person AS documentnumber,
        sp.Name AS empname,
        e.PayRollType AS payrolltype,
        CONVERT(VARCHAR(8), ISNULL(e.ReEntryDate, e.EntryDate), 112) AS entrydate,
        v.ControlYear AS controlyear,
        CASE
            WHEN CONVERT(VARCHAR(8), v.DateBeginProvision, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                CASE
                    WHEN CONVERT(VARCHAR(8), v.DateBeginRights, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                        ABS(
                            v.consumeddays
                                - ISNULL((
                                    SELECT SUM(vd.Days)
                                    FROM PR_VacationDetail vd
                                    WHERE vd.Person = v.Person
                                      AND vd.Line = v.Line
                                      AND vd.Company = v.Company
                                      AND vd.DateBegin > @date
                                ), 0)
                            - v.acquireddays
                        )
                    ELSE
                        ROUND((dbo.f_getDias360(v.DateBeginProvision, @date) * 2.5) / 30, 2)
                        - (
                            v.consumeddays
                            - ISNULL((
                                SELECT SUM(vd.Days)
                                FROM PR_VacationDetail vd
                                WHERE vd.Person = v.Person
                                  AND vd.Line = v.Line
                                  AND vd.Company = v.Company
                                  AND vd.DateBegin > @date
                            ), 0)
                        )
                END
            ELSE 0
        END AS porconsumir,
        v.DateBeginProvision AS inicioProvision,
        v.DateBeginRights AS finProvision
    INTO #VacSaldo
    FROM PR_Vacation v
        INNER JOIN PR_Employee e
            ON v.Person = e.Person
           AND e.Status = 'N'
        INNER JOIN SY_Person sp
            ON e.Person = sp.Person
    WHERE v.Company = @company
      AND (@person = '0' OR v.Person = @person)
      AND v.ControlYear < @year
      AND v.ControlYear >= YEAR(ISNULL(e.ReEntryDate, e.EntryDate))
      AND e.PayRollType = @payrolltype
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ABS(
            v.consumeddays
                - ISNULL((
                    SELECT SUM(vd.Days)
                    FROM PR_VacationDetail vd
                    WHERE vd.Person = v.Person
                      AND vd.Line = v.Line
                      AND vd.Company = v.Company
                      AND vd.DateBegin > @date
                ), 0)
            - v.acquireddays
        ) > 0;

    DELETE FROM xx_saldovacaciones;

    INSERT INTO xx_saldovacaciones (company, person, name, entrydate, payrolltype)
    SELECT DISTINCT
        @company,
        documentnumber,
        empname,
        entrydate,
        payrolltype
    FROM #VacSaldo;

    ;WITH Agg AS (
        SELECT
            documentnumber,
            MAX(CASE WHEN controlyear = @year - 5 THEN porconsumir END) AS saldo1,
            MAX(CASE WHEN controlyear = @year - 4 THEN porconsumir END) AS saldo2,
            MAX(CASE WHEN controlyear = @year - 3 THEN porconsumir END) AS saldo3,
            MAX(CASE WHEN controlyear = @year - 2 THEN porconsumir END) AS saldo4,
            MAX(CASE WHEN controlyear = @year - 1 THEN porconsumir END) AS saldo5,
            SUM(
                CASE
                    WHEN inicioProvision IS NOT NULL
                     AND finProvision IS NOT NULL
                     AND inicioProvision < finProvision
                        THEN dbo.f_count_medical_rest_days_web(
                            @company,
                            documentnumber,
                            '20',
                            inicioProvision,
                            finProvision,
                            0
                        )
                    ELSE 0
                END
            ) AS descansos
        FROM #VacSaldo
        GROUP BY documentnumber
    )
    UPDATE sv
    SET
        saldo1 = ISNULL(a.saldo1, 0),
        saldo2 = ISNULL(a.saldo2, 0),
        saldo3 = ISNULL(a.saldo3, 0),
        saldo4 = ISNULL(a.saldo4, 0),
        saldo5 = ISNULL(a.saldo5, 0),
        descansos = ISNULL(a.descansos, 0),
        faltas = dbo.f_count_medical_rest_days_web(
            sv.company,
            sv.person,
            '07',
            CONVERT(DATETIME, sv.entrydate, 112),
            @date,
            0
        ),
        licencias = dbo.f_count_medical_rest_days_web(
            sv.company,
            sv.person,
            '05',
            CONVERT(DATETIME, sv.entrydate, 112),
            @date,
            1
        )
    FROM xx_saldovacaciones sv
        INNER JOIN Agg a
            ON a.documentnumber = sv.person;

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

    DROP TABLE #VacSaldo;
END
GO
