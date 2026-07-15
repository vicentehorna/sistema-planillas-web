/*
    Alertas — liquidación de beneficios sociales pendiente para trabajadores cesados.

    Según normativa laboral peruana, la liquidación debe calcularse dentro de las
    48 horas posteriores al cese. Este SP lista trabajadores que:

      - Están activos en ficha (PR_Employee.Status = 'N').
      - Tienen fecha de cese en ficha (PR_Employee.CeaseDate).
      - Han pasado >= @dias_limite días desde el cese (default 2 = 48 horas).
      - Aún no tienen cálculo del proceso LIQUIDACION correspondiente a ese cese,
        identificado por PR_EmployeePayRoll.CeaseDate = PR_Employee.CeaseDate
        con concepto FormulaCode = LIQ_NETO en PR_EmployeePayRollConcept.

    Usado por: alertas del dashboard.

    Parámetros:
      @company      — compañía (obligatorio).
      @payrolltype  — tipo de planilla; '0' = todos.
      @fecha_corte  — fecha de corte; NULL = hoy.
      @dias_limite  — días mínimos desde el cese (default 2).

    Ejemplo:
      EXEC sp_pr_alertas_liquidacion_cese_pendiente_web
           @company = 'BGT',
           @payrolltype = '0',
           @fecha_corte = NULL,
           @dias_limite = 2;
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_alertas_liquidacion_cese_pendiente_web]
    @company      VARCHAR(4),
    @payrolltype  VARCHAR(20) = '0',
    @fecha_corte  DATETIME = NULL,
    @dias_limite  INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    IF @payrolltype = '' SET @payrolltype = '0';
    SET @fecha_corte = CAST(ISNULL(@fecha_corte, GETDATE()) AS DATE);
    SET @dias_limite = ISNULL(@dias_limite, 2);

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @dias_limite < 0
    BEGIN
        RAISERROR('El límite de días debe ser mayor o igual a cero.', 16, 1);
        RETURN;
    END;

    ;WITH cesados AS (
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
            CONVERT(DATE, ISNULL(e.ReEntryDate, e.EntryDate)) AS fecha_ingreso,
            CONVERT(DATE, e.CeaseDate) AS fecha_cese,
            e.CeaseReason AS ceasereason_id,
            ISNULL(cr.Description, '') AS motivo_cese,
            e.Status AS status_empleado,
            LEFT(CONVERT(VARCHAR(8), e.CeaseDate, 112), 6) AS periodo_cese_yyyymm,
            DATEDIFF(DAY, CONVERT(DATE, e.CeaseDate), @fecha_corte) AS dias_desde_cese
        FROM PR_Employee e (NOLOCK)
            INNER JOIN SY_Person sp (NOLOCK)
                ON e.Person = sp.Person
            INNER JOIN PR_PayRollType pt (NOLOCK)
                ON e.PayRollType = pt.PayRollType
               AND pt.Company = e.Company
            LEFT JOIN PR_CeaseReason cr (NOLOCK)
                ON e.CeaseReason = cr.CeaseReason
        WHERE e.Company = @company
          AND e.Status = 'N'
          AND e.CeaseDate IS NOT NULL
          AND CONVERT(DATE, e.CeaseDate) <= @fecha_corte
          AND DATEDIFF(DAY, CONVERT(DATE, e.CeaseDate), @fecha_corte) >= @dias_limite
          AND (@payrolltype = '0' OR e.PayRollType = @payrolltype)
    )
    SELECT
        c.company,
        c.person,
        c.employee_code,
        c.documento,
        c.nombre,
        c.payrolltype,
        c.tipoplanilla,
        c.tipoplanilla_desc,
        c.fecha_ingreso,
        c.fecha_cese,
        c.motivo_cese,
        c.status_empleado,
        c.periodo_cese_yyyymm,
        STUFF(c.periodo_cese_yyyymm, 5, 0, '-') AS periodo_cese,
        c.dias_desde_cese,
        CASE
            WHEN c.dias_desde_cese >= 2 THEN 'VENCIDO'
            ELSE 'EN_PLAZO'
        END AS estado_plazo,
        'Liquidar beneficios sociales: sin cálculo LIQUIDACION (LIQ_NETO) del periodo de cese.'
            AS motivo_alerta
    FROM cesados c
    WHERE NOT EXISTS (
        SELECT 1
        FROM PR_EmployeePayRollConcept epc (NOLOCK)
            INNER JOIN PR_Concept con (NOLOCK)
                ON epc.Concept = con.Concept
               AND epc.Company = con.Company
            INNER JOIN PR_ProcessType pt (NOLOCK)
                ON epc.ProcessType = pt.ProcessType
            INNER JOIN PR_EmployeePayRoll ep (NOLOCK)
                ON ep.Company = epc.Company
               AND ep.Person = epc.Person
               AND ep.PayRollType = epc.PayRollType
               AND ep.ProcessType = epc.ProcessType
               AND ep.PRPeriod = epc.PRPeriod
        WHERE epc.Company = c.company
          AND epc.Person = c.person
          AND LTRIM(RTRIM(pt.ShortName)) = 'LIQUIDACION'
          AND UPPER(LTRIM(RTRIM(ISNULL(con.FormulaCode, '')))) = 'LIQ_NETO'
          AND CONVERT(DATE, ep.CeaseDate) = c.fecha_cese
    )
    ORDER BY
        c.dias_desde_cese DESC,
        c.fecha_cese DESC,
        c.nombre,
        c.person;
END
GO
