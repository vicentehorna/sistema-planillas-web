/*
    Datos de vacaciones de un trabajador para Registro de Vacaciones.
    Usado por: POST /api/vacaciones/obtener (registro_vacaciones.html).

    Días anuales: prioriza PR_Employee.DiasVacaciones; si no hay, PR_PayRollType.DiasVacaciones (default 30).

    Devuelve 4 resultsets:
      1) Datos del empleado
      2) Resumen de saldo (acumulados, gozados, pendientes)
      3) Periodos vacacionales activos (PR_Vacation status='A')
      4) Detalle de utilización de periodos activos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_obtener_trabajador_web]
    @company VARCHAR(4),
    @person  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fecha_hoy DATE = CAST(GETDATE() AS DATE);
    DECLARE @dias_vacaciones DECIMAL(10, 2);

    SELECT @dias_vacaciones = CAST(
        ISNULL(NULLIF(e.DiasVacaciones, 0), ISNULL(pt.DiasVacaciones, 30)) AS DECIMAL(10, 2)
    )
    FROM PR_Employee e
        LEFT JOIN PR_PayRollType pt
            ON pt.Company = e.Company
           AND pt.PayRollType = e.PayRollType
    WHERE e.Company = @company
      AND e.Person = @person;

    IF @dias_vacaciones IS NULL OR @dias_vacaciones <= 0
        SET @dias_vacaciones = 30;

    /* 1) Empleado */
    SELECT
        PR_EMPLOYEE.PERSON AS person,
        PR_EMPLOYEE.EMPLOYEECODE AS codigo,
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS nombre,
        SY_PERSON.DOCUMENTNUMBER AS documento,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS fechaingreso,
        PR_EMPLOYEE.PAYROLLTYPE AS payrolltype,
        PR_PAYROLLTYPE.DESCRIPTION AS tipoplanilla,
        CAST(@dias_vacaciones AS INT) AS diasvacaciones
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_PAYROLLTYPE
            ON PR_EMPLOYEE.PAYROLLTYPE = PR_PAYROLLTYPE.PAYROLLTYPE
    WHERE PR_EMPLOYEE.COMPANY = @company
      AND PR_EMPLOYEE.PERSON = @person;

    /* Periodos con días adquiridos calculados (misma lógica para resumen y grilla) */
    ;WITH periodos AS (
        SELECT
            v.line,
            v.controlyear,
            CAST(v.controlyear AS VARCHAR(4)) + '-' + CAST(CAST(v.controlyear AS INT) + 1 AS VARCHAR(4)) AS periodo,
            /* Sin consumo: muestra días del trabajador. Con consumo: conserva histórico del periodo. */
            CASE
                WHEN ISNULL(v.consumeddays, 0) = 0 THEN CAST(@dias_vacaciones AS INT)
                ELSE CAST(ISNULL(v.days, @dias_vacaciones) AS INT)
            END AS dias,
            CASE
                WHEN CAST(v.DateBeginProvision AS DATE) > @fecha_hoy THEN CAST(0 AS DECIMAL(10, 2))
                WHEN CAST(v.DateBeginRights AS DATE) <= @fecha_hoy THEN
                    CASE
                        WHEN ISNULL(v.consumeddays, 0) = 0 THEN @dias_vacaciones
                        ELSE CAST(ISNULL(v.AcquiredDays, 0) AS DECIMAL(10, 2))
                    END
                ELSE ROUND(dbo.f_getDias360(v.DateBeginProvision, @fecha_hoy) * @dias_vacaciones / 360.0, 2)
            END AS dias_adquiridos,
            CAST(ISNULL(v.consumeddays, 0) AS DECIMAL(10, 2)) AS consumidos,
            ISNULL(v.payeddays, 0) AS pagados,
            v.DateBeginProvision AS inicio_provision,
            v.DateBeginRights AS inicio_derecho,
            v.DateEndRights AS fin_derecho,
            v.DateEndNormal AS limite_sin_indemnizacion,
            v.status,
            CASE v.status WHEN 'A' THEN 'Activo' WHEN 'I' THEN 'Inactivo' ELSE v.status END AS estado_texto,
            v.XLastUser AS usuario,
            v.XLastDate AS fecha_modificacion
        FROM PR_Vacation v
        WHERE v.company = @company
          AND v.person = @person
          AND v.status = 'A'
    )
    /* 2) Resumen */
    SELECT
        ISNULL(SUM(dias_adquiridos), 0) AS dias_acumulados,
        ISNULL(SUM(consumidos), 0) AS dias_gozados,
        ISNULL(SUM(dias_adquiridos - consumidos), 0) AS dias_pendientes
    FROM periodos;

    /* 3) Periodos */
    ;WITH periodos AS (
        SELECT
            v.line,
            v.controlyear,
            CAST(v.controlyear AS VARCHAR(4)) + '-' + CAST(CAST(v.controlyear AS INT) + 1 AS VARCHAR(4)) AS periodo,
            CASE
                WHEN ISNULL(v.consumeddays, 0) = 0 THEN CAST(@dias_vacaciones AS INT)
                ELSE CAST(ISNULL(v.days, @dias_vacaciones) AS INT)
            END AS dias,
            CASE
                WHEN CAST(v.DateBeginProvision AS DATE) > @fecha_hoy THEN CAST(0 AS DECIMAL(10, 2))
                WHEN CAST(v.DateBeginRights AS DATE) <= @fecha_hoy THEN
                    CASE
                        WHEN ISNULL(v.consumeddays, 0) = 0 THEN @dias_vacaciones
                        ELSE CAST(ISNULL(v.AcquiredDays, 0) AS DECIMAL(10, 2))
                    END
                ELSE ROUND(dbo.f_getDias360(v.DateBeginProvision, @fecha_hoy) * @dias_vacaciones / 360.0, 2)
            END AS dias_adquiridos,
            CAST(ISNULL(v.consumeddays, 0) AS DECIMAL(10, 2)) AS consumidos,
            ISNULL(v.payeddays, 0) AS pagados,
            v.DateBeginProvision AS inicio_provision,
            v.DateBeginRights AS inicio_derecho,
            v.DateEndRights AS fin_derecho,
            v.DateEndNormal AS limite_sin_indemnizacion,
            v.status,
            CASE v.status WHEN 'A' THEN 'Activo' WHEN 'I' THEN 'Inactivo' ELSE v.status END AS estado_texto,
            v.XLastUser AS usuario,
            v.XLastDate AS fecha_modificacion
        FROM PR_Vacation v
        WHERE v.company = @company
          AND v.person = @person
          AND v.status = 'A'
    )
    SELECT
        line,
        controlyear,
        periodo,
        dias,
        dias_adquiridos,
        consumidos,
        dias_adquiridos - consumidos AS pendientes,
        pagados,
        dias - pagados AS por_pagar,
        inicio_provision,
        inicio_derecho,
        fin_derecho,
        limite_sin_indemnizacion,
        status,
        estado_texto,
        usuario,
        fecha_modificacion
    FROM periodos
    ORDER BY controlyear DESC;

    /* 4) Detalle de utilización — solo periodos activos */
    SELECT
        d.line,
        d.secuence,
        d.prperiod,
        CASE
            WHEN LEN(LTRIM(RTRIM(ISNULL(d.prperiod, '')))) >= 6
                 AND SUBSTRING(d.prperiod, 1, 6) NOT LIKE '%[^0-9]%'
            THEN SUBSTRING(d.prperiod, 1, 4) + '-' + SUBSTRING(d.prperiod, 5, 2)
            ELSE d.prperiod
        END AS consumo_efectivo,
        d.datebegin AS fecha_inicio,
        d.dateend AS fecha_fin,
        ISNULL(d.days, 0) AS dias,
        d.vacationtype,
        CASE d.vacationtype
            WHEN 'D' THEN 'Descanso'
            WHEN 'V' THEN 'Venta'
            WHEN 'X' THEN 'No Remunerada'
            ELSE d.vacationtype
        END AS tipo_texto,
        d.XLastUser AS usuario,
        d.XLastDate AS fecha_modificacion
    FROM PR_VacationDetail d
        INNER JOIN PR_Vacation v
            ON v.Company = d.Company
           AND v.Person = d.Person
           AND v.line = d.line
           AND v.status = 'A'
    WHERE d.company = @company
      AND d.person = @person
    ORDER BY d.datebegin ASC;
END
GO
