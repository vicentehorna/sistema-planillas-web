/*
    Trabajadores elegibles para el cálculo de planilla (módulo Procesar planilla).
    Devuelve nombre, person, fechas de ingreso/reingreso, cese y última fecha de cálculo.

    @cia, @payrolltype, @processtype, @period: obligatorios para fecha de cálculo.
    @cesados: T = activos + cesados del mes del periodo, Y = solo cesados del mes, N = sin fecha de cese.
    @repunit: '0' = todas las unidades; otro valor filtra SY_Person.ReplicationUnit.
    @accountprofile: '' o '0' = todos; otro valor filtra PR_Employee.AccountProfile.

    Solo incluye trabajadores con fecha de ingreso/reingreso <= ultimo dia del mes del periodo.
    Los cesados de meses anteriores al periodo no se listan (p. ej. cese en mayo no aparece en junio).

    Si el proceso es VACACIONES (ShortName o Description), solo lista quienes tienen
    PR_VacationDetail en ese periodo con VacationType D (tomadas) o V (vendidas).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_calcularplanillas_web]
    @cia            VARCHAR(10),
    @payrolltype    VARCHAR(20),
    @processtype    VARCHAR(20),
    @period         VARCHAR(10),
    @cesados        CHAR(1),
    @repunit        VARCHAR(20),
    @accountprofile VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia, ''))), 10);
    SET @payrolltype = LEFT(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), 20);
    SET @processtype = LEFT(LTRIM(RTRIM(ISNULL(@processtype, ''))), 20);
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 10);

    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';
    SET @accountprofile = LTRIM(RTRIM(ISNULL(@accountprofile, '')));
    IF @accountprofile = '0' SET @accountprofile = '';

    DECLARE @fecha_inicio_mes DATE;
    DECLARE @fecha_fin_mes DATE;
    DECLARE @period_ym CHAR(6);

    SET @period_ym = LEFT(@period, 6);
    IF LEN(@period_ym) = 6 AND @period_ym NOT LIKE '%[^0-9]%'
    BEGIN
        SET @fecha_inicio_mes = CONVERT(DATE, @period_ym + '01', 112);
        SET @fecha_fin_mes = EOMONTH(@fecha_inicio_mes);
    END;

    DECLARE @es_vacaciones BIT = 0;
    IF EXISTS (
        SELECT 1
        FROM PR_ProcessType
        WHERE ProcessType = @processtype
          AND (
                LTRIM(RTRIM(ShortName)) = 'VACACIONES'
             OR LTRIM(RTRIM(Description)) = 'VACACIONES'
          )
    )
        SET @es_vacaciones = 1;

    SELECT
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS [name],
        PR_EMPLOYEE.PERSON AS person,
        PR_EMPLOYEE.COMPANY AS company,
        PR_EMPLOYEE.PAYROLLTYPE AS payrolltype,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS entrydate,
        PR_EMPLOYEE.CEASEDATE AS ceasedate,
        EPR.XLastDate AS calculationdate
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_EmployeePayRoll EPR
            ON EPR.Person = PR_EMPLOYEE.Person
           AND EPR.Company = @cia
           AND EPR.PayRollType = @payrolltype
           AND EPR.ProcessType = @processtype
           AND LTRIM(RTRIM(EPR.PRPeriod)) = @period
    WHERE PR_EMPLOYEE.COMPANY = @cia
      AND PR_EMPLOYEE.PAYROLLTYPE = @payrolltype
      AND PR_EMPLOYEE.STATUS = 'N'
      AND (
            (
                @cesados = 'T'
                AND (
                    PR_EMPLOYEE.CEASEDATE IS NULL
                    OR @fecha_inicio_mes IS NULL
                    OR CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) >= @fecha_inicio_mes
                )
            )
            OR (
                @cesados = 'Y'
                AND @fecha_inicio_mes IS NOT NULL
                AND @fecha_fin_mes IS NOT NULL
                AND PR_EMPLOYEE.CEASEDATE IS NOT NULL
                AND CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) >= @fecha_inicio_mes
                AND CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) <= @fecha_fin_mes
            )
            OR (
                @cesados = 'N'
                AND PR_EMPLOYEE.CEASEDATE IS NULL
            )
      )
      AND (@repunit = '0' OR SY_PERSON.REPLICATIONUNIT = @repunit)
      AND (
            @accountprofile = ''
            OR LTRIM(RTRIM(ISNULL(PR_EMPLOYEE.AccountProfile, ''))) = @accountprofile
      )
      AND (
            @fecha_fin_mes IS NULL
            OR CONVERT(DATE, ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE)) <= @fecha_fin_mes
      )
      AND (
            @es_vacaciones = 0
            OR EXISTS (
                SELECT 1
                FROM PR_VacationDetail vd
                WHERE vd.Company = PR_EMPLOYEE.COMPANY
                  AND vd.Person = PR_EMPLOYEE.PERSON
                  AND LTRIM(RTRIM(vd.PRPeriod)) = @period
                  AND UPPER(LTRIM(RTRIM(ISNULL(vd.VacationType, '')))) IN ('D', 'V')
            )
      )
    ORDER BY [name], person;
END
GO
