/*
    Datos de vacaciones de un trabajador para Registro de Vacaciones.
    Usado por: POST /api/vacaciones/obtener (registro_vacaciones.html).

    Devuelve 4 resultsets:
      1) Datos del empleado
      2) Resumen de saldo (acumulados, gozados, pendientes)
      3) Periodos vacacionales (PR_Vacation)
      4) Detalle de utilización (PR_VacationDetail)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_obtener_trabajador_web]
    @company VARCHAR(4),
    @person  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

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
        PR_PAYROLLTYPE.DESCRIPTION AS tipoplanilla
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_PAYROLLTYPE
            ON PR_EMPLOYEE.PAYROLLTYPE = PR_PAYROLLTYPE.PAYROLLTYPE
    WHERE PR_EMPLOYEE.COMPANY = @company
      AND PR_EMPLOYEE.PERSON = @person;

    /* 2) Resumen */
    SELECT
        ISNULL(SUM(CASE WHEN v.status = 'A' THEN ISNULL(v.AcquiredDays, 0) ELSE 0 END), 0) AS dias_acumulados,
        ISNULL(SUM(CASE WHEN v.status = 'A' THEN ISNULL(v.consumeddays, 0) ELSE 0 END), 0) AS dias_gozados,
        ISNULL(SUM(
            CASE
                WHEN v.status = 'A' THEN ABS(ISNULL(v.consumeddays, 0) - ISNULL(v.AcquiredDays, 0))
                ELSE 0
            END
        ), 0) AS dias_pendientes
    FROM PR_Vacation v
    WHERE v.company = @company
      AND v.person = @person;

    /* 3) Periodos vacacionales — adquiridos = días ganados a la fecha (misma lógica que sp_pr_saldovacaciones_web) */
    DECLARE @fecha_hoy DATE = CAST(GETDATE() AS DATE);
    DECLARE @dias_vacaciones DECIMAL(10, 2);

    SELECT @dias_vacaciones = CAST(ISNULL(pt.DiasVacaciones, 30) AS DECIMAL(10, 2))
    FROM PR_Employee e
        INNER JOIN PR_PayRollType pt
            ON pt.Company = e.Company
           AND pt.PayRollType = e.PayRollType
    WHERE e.Company = @company
      AND e.Person = @person;

    IF @dias_vacaciones IS NULL OR @dias_vacaciones <= 0
        SET @dias_vacaciones = 30;

    SELECT
        v.line,
        v.controlyear,
        CAST(v.controlyear AS VARCHAR(4)) + '-' + CAST(CAST(v.controlyear AS INT) + 1 AS VARCHAR(4)) AS periodo,
        ISNULL(v.days, 0) AS dias,
        CASE
            WHEN CAST(v.DateBeginProvision AS DATE) > @fecha_hoy THEN CAST(0 AS DECIMAL(10, 2))
            WHEN CAST(v.DateBeginRights AS DATE) <= @fecha_hoy THEN CAST(ISNULL(v.AcquiredDays, 0) AS DECIMAL(10, 2))
            ELSE ROUND(dbo.f_getDias360(v.DateBeginProvision, @fecha_hoy) * @dias_vacaciones / 360.0, 2)
        END AS dias_adquiridos,
        CAST(ISNULL(v.consumeddays, 0) AS DECIMAL(10, 2)) AS consumidos,
        CASE
            WHEN CAST(v.DateBeginProvision AS DATE) > @fecha_hoy THEN CAST(0 AS DECIMAL(10, 2))
            ELSE
                CASE
                    WHEN CAST(v.DateBeginRights AS DATE) <= @fecha_hoy THEN CAST(ISNULL(v.AcquiredDays, 0) AS DECIMAL(10, 2))
                    ELSE ROUND(dbo.f_getDias360(v.DateBeginProvision, @fecha_hoy) * @dias_vacaciones / 360.0, 2)
                END
                - CAST(ISNULL(v.consumeddays, 0) AS DECIMAL(10, 2))
        END AS pendientes,
        ISNULL(v.payeddays, 0) AS pagados,
        ISNULL(v.AcquiredDays, 0) - ISNULL(v.payeddays, 0) AS por_pagar,
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
    ORDER BY v.controlyear DESC;

    /* 4) Detalle de utilización */
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
    WHERE d.company = @company
      AND d.person = @person
    ORDER BY d.datebegin ASC;
END
GO
