/*
    Alertas — trabajadores con vacaciones pendientes de programar.

    Identifica, por cada periodo vacacional (PR_Vacation / ControlYear), trabajadores
    activos (Status = 'N' y sin cese) que acumulan >= @dias_umbral días
    (2.5 por mes trabajado) y no registran goce de vacaciones en
    PR_VacationDetail (VacationType = 'D').

    Fecha base de acumulación:
      ISNULL(ReEntryDate, EntryDate)
      — si hay reingreso, solo cuentan periodos con DateBeginProvision >= esa fecha
        y la acumulación se calcula desde el reingreso (no desde el ingreso original).

    Validación por periodo:
      - Cada ControlYear se evalúa de forma independiente.
      - Si el trabajador gozó sus 30 días del 2024, el periodo 2025 se valida aparte.

    Cálculo de días acumulados (misma lógica que saldo de vacaciones):
      - Si ya inició el derecho (DateBeginRights <= fecha corte): AcquiredDays.
      - Si aún está en periodo de acumulación: f_getDias360 * 2.5 / 30
        desde MAX(inicio_provision, fecha_base).

    Usado por: alertas del dashboard (fase 1: listado en hm_aci2).

    Parámetros:
      @company      — compañía (obligatorio).
      @payrolltype  — tipo de planilla; '0' = todos.
      @fecha_corte  — fecha de corte; NULL = hoy.
      @dias_umbral  — umbral de alerta (default 28).

    Exclusiones:
      - No incluye planillas de Construcción Civil (ShortName/Description
        con CONSTRUCCION, p.ej. CONSTRUCCION CIVIL).

    Ejemplo:
      EXEC sp_pr_alertas_vacaciones_pendientes_web
           @company = 'BGT',
           @payrolltype = '0',
           @fecha_corte = NULL,
           @dias_umbral = 28;
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_alertas_vacaciones_pendientes_web]
    @company      VARCHAR(4),
    @payrolltype  VARCHAR(20) = '0',
    @fecha_corte  DATETIME = NULL,
    @dias_umbral  DECIMAL(10, 2) = 28
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    IF @payrolltype = '' SET @payrolltype = '0';
    SET @fecha_corte = CAST(ISNULL(@fecha_corte, GETDATE()) AS DATE);
    SET @dias_umbral = ISNULL(@dias_umbral, 28);

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @dias_umbral < 0
    BEGIN
        RAISERROR('El umbral de días debe ser mayor o igual a cero.', 16, 1);
        RETURN;
    END;

    ;WITH periodos AS (
        SELECT
            e.Company AS company,
            e.Person AS person,
            e.EmployeeCode AS employee_code,
            e.PayRollType AS payrolltype,
            LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) AS nombre,
            sp.DocumentNumber AS documento,
            pt.ShortName AS tipoplanilla,
            pt.Description AS tipoplanilla_desc,
            fb.fecha_base AS fecha_ingreso,
            CONVERT(DATE, e.ReEntryDate) AS fecha_reingreso,
            v.Line AS line,
            v.ControlYear AS control_year,
            CAST(v.ControlYear AS VARCHAR(4)) + '-'
                + CAST(CAST(v.ControlYear AS INT) + 1 AS VARCHAR(4)) AS periodo_vacacional,
            CONVERT(DATE, v.DateBeginProvision) AS inicio_provision,
            CONVERT(DATE, v.DateBeginRights) AS inicio_derecho,
            CONVERT(DATE, v.DateEndRights) AS fin_derecho,
            CONVERT(DATE, v.DateEndNormal) AS limite_sin_indemnizacion,
            ISNULL(v.AcquiredDays, ISNULL(v.Days, 30)) AS dias_adquiridos,
            CASE
                WHEN CONVERT(DATE, v.DateBeginRights) <= @fecha_corte THEN
                    CAST(ISNULL(v.AcquiredDays, ISNULL(v.Days, 30)) AS DECIMAL(10, 2))
                ELSE
                    ROUND(
                        (
                            dbo.f_getDias360(
                                CASE
                                    WHEN CONVERT(DATE, v.DateBeginProvision) > fb.fecha_base
                                    THEN CONVERT(DATE, v.DateBeginProvision)
                                    ELSE fb.fecha_base
                                END,
                                @fecha_corte
                            ) * 2.5
                        ) / 30.0,
                        2
                    )
            END AS dias_acumulados,
            ISNULL(gz.gozados_total, 0) AS dias_gozados,
            ISNULL(gz.gozados_efectivos, 0) AS dias_gozados_efectivos,
            ISNULL(gz.programados_futuro, 0) AS dias_programados_futuro
        FROM PR_Employee e (NOLOCK)
            INNER JOIN SY_Person sp (NOLOCK)
                ON e.Person = sp.Person
            INNER JOIN PR_PayRollType pt (NOLOCK)
                ON e.PayRollType = pt.PayRollType
               AND pt.Company = e.Company
            CROSS APPLY (
                SELECT CONVERT(DATE, ISNULL(e.ReEntryDate, e.EntryDate)) AS fecha_base
            ) fb
            INNER JOIN PR_Vacation v (NOLOCK)
                ON v.Person = e.Person
               AND v.Company = e.Company
               AND ISNULL(v.status, 'A') = 'A'
            OUTER APPLY (
                SELECT
                    SUM(ISNULL(vd.Days, 0)) AS gozados_total,
                    SUM(
                        CASE
                            WHEN CONVERT(DATE, vd.DateBegin) <= @fecha_corte
                            THEN ISNULL(vd.Days, 0)
                            ELSE 0
                        END
                    ) AS gozados_efectivos,
                    SUM(
                        CASE
                            WHEN CONVERT(DATE, vd.DateBegin) > @fecha_corte
                            THEN ISNULL(vd.Days, 0)
                            ELSE 0
                        END
                    ) AS programados_futuro
                FROM PR_VacationDetail vd (NOLOCK)
                WHERE vd.Company = v.Company
                  AND vd.Person = v.Person
                  AND vd.Line = v.Line
                  AND LTRIM(RTRIM(ISNULL(vd.VacationType, ''))) = 'D'
            ) gz
        WHERE e.Company = @company
          AND e.Status = 'N'
          AND e.CeaseDate IS NULL
          AND fb.fecha_base IS NOT NULL
          AND fb.fecha_base <= @fecha_corte
          AND (@payrolltype = '0' OR e.PayRollType = @payrolltype)
          /* Construcción Civil no aplica a esta alerta. */
          AND UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) NOT LIKE '%CONSTRUCCION%'
          AND UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) NOT LIKE '%CONSTRUCCION%'
          /* Solo periodos del ciclo laboral actual (desde reingreso/ingreso). */
          AND CONVERT(DATE, v.DateBeginProvision) >= fb.fecha_base
          AND CONVERT(DATE, v.DateBeginProvision) <= @fecha_corte
    )
    SELECT
        p.company,
        p.person,
        p.employee_code,
        p.documento,
        p.nombre,
        p.payrolltype,
        p.tipoplanilla,
        p.tipoplanilla_desc,
        p.fecha_ingreso,
        p.fecha_reingreso,
        p.line,
        p.control_year,
        p.periodo_vacacional,
        p.inicio_provision,
        p.inicio_derecho,
        p.fin_derecho,
        p.limite_sin_indemnizacion,
        p.dias_adquiridos,
        p.dias_acumulados,
        p.dias_gozados,
        p.dias_gozados_efectivos,
        p.dias_programados_futuro,
        CAST(
            CASE
                WHEN p.dias_acumulados > p.dias_gozados
                THEN p.dias_acumulados - p.dias_gozados
                ELSE 0
            END AS DECIMAL(10, 2)
        ) AS dias_pendientes,
        CASE
            WHEN CONVERT(DATE, p.inicio_derecho) <= @fecha_corte THEN 'DERECHO_VENCIDO'
            ELSE 'ACUMULACION_PREVIA'
        END AS estado_periodo,
        'Programar vacaciones: acumulado >= '
            + CAST(@dias_umbral AS VARCHAR(10))
            + ' días sin goce registrado en el periodo.' AS motivo_alerta
    FROM periodos p
    WHERE p.dias_acumulados >= @dias_umbral
      AND ISNULL(p.dias_gozados, 0) = 0
    ORDER BY
        p.dias_acumulados DESC,
        p.inicio_derecho ASC,
        p.nombre,
        p.person,
        p.control_year;
END
GO
