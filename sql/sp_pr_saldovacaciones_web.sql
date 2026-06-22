/*
    Saldo de vacaciones por trabajador y año de control.
    Usado por: POST /reporte_saldo_vacaciones (reporte_saldo_vacaciones.html).

    Requiere: f_getDias360.
    Solo tablas temporales (#): no usa xx_saldovacaciones ni actualiza PR_Vacation.
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

    IF OBJECT_ID('tempdb..#FutureVac') IS NOT NULL DROP TABLE #FutureVac;
    IF OBJECT_ID('tempdb..#VacSaldo') IS NOT NULL DROP TABLE #VacSaldo;
    IF OBJECT_ID('tempdb..#Persons') IS NOT NULL DROP TABLE #Persons;
    IF OBJECT_ID('tempdb..#SaldoAgg') IS NOT NULL DROP TABLE #SaldoAgg;
    IF OBJECT_ID('tempdb..#MedEntry') IS NOT NULL DROP TABLE #MedEntry;
    IF OBJECT_ID('tempdb..#MedDescansos') IS NOT NULL DROP TABLE #MedDescansos;
    IF OBJECT_ID('tempdb..#Result') IS NOT NULL DROP TABLE #Result;

    SELECT
        vd.Person,
        vd.Line,
        vd.Company,
        SUM(vd.Days) AS future_days
    INTO #FutureVac
    FROM PR_VacationDetail vd
    WHERE vd.Company = @company
      AND vd.DateBegin > @date
      AND (@person = '0' OR vd.Person = @person)
    GROUP BY vd.Person, vd.Line, vd.Company;

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
                            (v.consumeddays - ISNULL(fv.future_days, 0)) - v.acquireddays
                        )
                    ELSE
                        ROUND((dbo.f_getDias360(v.DateBeginProvision, @date) * 2.5) / 30, 2)
                        - (v.consumeddays - ISNULL(fv.future_days, 0))
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
        LEFT JOIN #FutureVac fv
            ON fv.Person = v.Person
           AND fv.Line = v.Line
           AND fv.Company = v.Company
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
      AND ABS((v.consumeddays - ISNULL(fv.future_days, 0)) - v.acquireddays) > 0;

    SELECT DISTINCT
        documentnumber,
        empname,
        entrydate,
        payrolltype
    INTO #Persons
    FROM #VacSaldo;

    SELECT
        documentnumber,
        MAX(CASE WHEN controlyear = @year - 5 THEN porconsumir END) AS saldo1,
        MAX(CASE WHEN controlyear = @year - 4 THEN porconsumir END) AS saldo2,
        MAX(CASE WHEN controlyear = @year - 3 THEN porconsumir END) AS saldo3,
        MAX(CASE WHEN controlyear = @year - 2 THEN porconsumir END) AS saldo4,
        MAX(CASE WHEN controlyear = @year - 1 THEN porconsumir END) AS saldo5
    INTO #SaldoAgg
    FROM #VacSaldo
    GROUP BY documentnumber;

    SELECT
        p.documentnumber AS person,
        SUM(
            CASE
                WHEN mrt.PDT = '07'
                 AND bounds_f.rs <= bounds_f.re
                    THEN DATEDIFF(DAY, bounds_f.rs, bounds_f.re) + 1
                ELSE 0
            END
        ) AS faltas,
        SUM(
            CASE
                WHEN mrt.PDT = '05'
                 AND bounds_l.rs <= bounds_l.re
                    THEN DATEDIFF(DAY, bounds_l.rs, bounds_l.re) + 1
                ELSE 0
            END
        ) AS licencias
    INTO #MedEntry
    FROM #Persons p
        INNER JOIN PR_EmployeeMedicalRest emr
            ON emr.Person = p.documentnumber
           AND emr.Company = @company
        INNER JOIN PR_MedicalRestType mrt
            ON emr.MedicalRestType = mrt.MedicalRestType
           AND mrt.PDT IN ('05', '07')
        CROSS APPLY (
            SELECT CONVERT(DATE, CONVERT(DATETIME, p.entrydate, 112)) AS entry_dt
        ) ed
        CROSS APPLY (
            SELECT
                CASE
                    WHEN CAST(emr.DateBegin AS DATE) > ed.entry_dt THEN CAST(emr.DateBegin AS DATE)
                    ELSE ed.entry_dt
                END AS rs,
                CASE
                    WHEN CAST(emr.DateEnd AS DATE) < DATEADD(DAY, -1, @date) THEN CAST(emr.DateEnd AS DATE)
                    ELSE DATEADD(DAY, -1, @date)
                END AS re
        ) bounds_f
        CROSS APPLY (
            SELECT
                CASE
                    WHEN CAST(emr.DateBegin AS DATE) > ed.entry_dt THEN CAST(emr.DateBegin AS DATE)
                    ELSE ed.entry_dt
                END AS rs,
                CASE
                    WHEN CAST(emr.DateEnd AS DATE) < @date THEN CAST(emr.DateEnd AS DATE)
                    ELSE @date
                END AS re
        ) bounds_l
    WHERE CAST(emr.DateBegin AS DATE) <= @date
      AND CAST(emr.DateEnd AS DATE) >= ed.entry_dt
    GROUP BY p.documentnumber;

    SELECT
        vs.documentnumber,
        SUM(
            CASE
                WHEN bounds.rs <= bounds.re THEN DATEDIFF(DAY, bounds.rs, bounds.re) + 1
                ELSE 0
            END
        ) AS descansos
    INTO #MedDescansos
    FROM #VacSaldo vs
        INNER JOIN PR_EmployeeMedicalRest emr
            ON emr.Person = vs.documentnumber
           AND emr.Company = @company
        INNER JOIN PR_MedicalRestType mrt
            ON emr.MedicalRestType = mrt.MedicalRestType
           AND mrt.PDT = '20'
        CROSS APPLY (
            SELECT
                CASE
                    WHEN CAST(vs.inicioProvision AS DATE) > CAST(emr.DateBegin AS DATE)
                        THEN CAST(vs.inicioProvision AS DATE)
                    ELSE CAST(emr.DateBegin AS DATE)
                END AS rs,
                CASE
                    WHEN CAST(DATEADD(DAY, -1, vs.finProvision) AS DATE) < CAST(emr.DateEnd AS DATE)
                        THEN CAST(DATEADD(DAY, -1, vs.finProvision) AS DATE)
                    ELSE CAST(emr.DateEnd AS DATE)
                END AS re
        ) bounds
    WHERE vs.inicioProvision IS NOT NULL
      AND vs.finProvision IS NOT NULL
      AND vs.inicioProvision < vs.finProvision
      AND CAST(emr.DateBegin AS DATE) <= CAST(DATEADD(DAY, -1, vs.finProvision) AS DATE)
      AND CAST(emr.DateEnd AS DATE) >= CAST(vs.inicioProvision AS DATE)
    GROUP BY vs.documentnumber;

    SELECT
        p.documentnumber AS person,
        p.empname AS name,
        p.entrydate,
        p.payrolltype,
        @company AS company,
        ISNULL(sa.saldo1, 0) AS saldo1,
        ISNULL(sa.saldo2, 0) AS saldo2,
        ISNULL(sa.saldo3, 0) AS saldo3,
        ISNULL(sa.saldo4, 0) AS saldo4,
        ISNULL(sa.saldo5, 0) AS saldo5,
        ISNULL(me.faltas, 0) AS faltas,
        ISNULL(me.licencias, 0) AS licencias,
        ISNULL(md.descansos, 0) AS descansos
    INTO #Result
    FROM #Persons p
        LEFT JOIN #SaldoAgg sa
            ON sa.documentnumber = p.documentnumber
        LEFT JOIN #MedEntry me
            ON me.person = p.documentnumber
        LEFT JOIN #MedDescansos md
            ON md.documentnumber = p.documentnumber;

    SELECT
        PR_PayRollType.ShortName AS tipoplanillas,
        r.person AS person,
        r.name,
        SY_ReplicationUnit.Description AS description,
        CONVERT(DATETIME, ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate)) AS entrydate,
        PR_Employee.CeaseDate AS ceasedate,
        r.saldo1,
        r.saldo2,
        r.saldo3,
        r.saldo4,
        r.saldo5,
        r.faltas,
        r.licencias,
        r.descansos,
        ROUND(
            r.saldo1 + r.saldo2 + r.saldo3 + r.saldo4 + r.saldo5
            - ROUND(r.faltas * 2.5 / 30.0, 2)
            - ROUND(r.licencias * 2.5 / 30.0, 2)
            - CASE
                WHEN r.descansos >= 60
                THEN ROUND(r.descansos * 2.5 / 30.0, 2)
                ELSE 0
              END,
            2
        ) AS saldo
    FROM #Result r
        INNER JOIN PR_PayRollType
            ON r.payrolltype = PR_PayRollType.PayRollType
        INNER JOIN PR_Employee
            ON r.person = PR_Employee.Person
           AND r.company = PR_Employee.Company
        INNER JOIN SY_Person
            ON r.person = SY_Person.Person
        LEFT JOIN SY_ReplicationUnit
            ON SY_Person.ReplicationUnit = SY_ReplicationUnit.ReplicationUnit
    ORDER BY r.name;

    DROP TABLE #FutureVac;
    DROP TABLE #VacSaldo;
    DROP TABLE #Persons;
    DROP TABLE #SaldoAgg;
    DROP TABLE #MedEntry;
    DROP TABLE #MedDescansos;
    DROP TABLE #Result;
END
GO
