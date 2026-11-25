/*
    Detalle de vacaciones por trabajador (reporte R019).
    Usado por: POST /reporte_vacaciones_detalle (reporte_vacaciones_detalle.html).

    Parámetros:
      @cia, @payrolltype — obligatorios.
      @period — '0' = todos los periodos; otro valor filtra por YYYYMM (primeros 6 caracteres).
      @person — '0' = todos los trabajadores; otro valor filtra por código person.
      @incluir_pagados — 'Y' = también lista PR_VacationPay (tipo D) del periodo
                         cuando NO existe detalle de utilización equivalente;
                         'N' (default) = solo PR_VacationDetail.

    Solo trabajadores activos (PR_Employee.Status = 'N').
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_r019_vacationdetail_web]
    @cia              VARCHAR(20),
    @payrolltype      VARCHAR(20),
    @period           VARCHAR(20),
    @person           VARCHAR(20),
    @incluir_pagados  VARCHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@period, '')) = '' SET @period = '0';
    SET @incluir_pagados = UPPER(LEFT(RTRIM(ISNULL(@incluir_pagados, 'N')), 1));
    IF @incluir_pagados NOT IN ('Y', 'N') SET @incluir_pagados = 'N';

    ;WITH detalle AS (
        SELECT
            vd.PRPeriod AS prperiod,
            e.Person AS person,
            LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) AS name,
            vd.DateBegin AS datebegin,
            vd.DateEnd AS dateend,
            vd.Days AS days,
            v.ControlYear AS controlyear,
            sp.DocumentNumber AS documentnumber,
            pos.Description AS cargo,
            CAST('Utilización' AS VARCHAR(20)) AS origen
        FROM PR_VacationDetail vd
            INNER JOIN PR_Vacation v (NOLOCK)
                ON vd.Person = v.Person
               AND vd.Company = v.Company
               AND vd.Line = v.Line
            INNER JOIN PR_Employee e (NOLOCK)
                ON vd.Person = e.Person
               AND vd.Company = e.Company
            INNER JOIN SY_Person sp (NOLOCK)
                ON vd.Person = sp.Person
            INNER JOIN PR_PayRollType pt (NOLOCK)
                ON e.PayRollType = pt.PayRollType
            LEFT JOIN PR_Position pos (NOLOCK)
                ON e.Position = pos.Position
        WHERE vd.Company = @cia
          AND e.PayRollType = @payrolltype
          AND (@person = '0' OR e.Person = @person)
          AND (@period = '0' OR LEFT(vd.PRPeriod, 6) = LEFT(@period, 6))
          AND e.Status = 'N'

        UNION ALL

        SELECT
            vp.PRPeriod AS prperiod,
            e.Person AS person,
            LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) AS name,
            vp.DateBegin AS datebegin,
            vp.DateEnd AS dateend,
            vp.Days AS days,
            v.ControlYear AS controlyear,
            sp.DocumentNumber AS documentnumber,
            pos.Description AS cargo,
            CAST('Pagado' AS VARCHAR(20)) AS origen
        FROM PR_VacationPay vp
            INNER JOIN PR_Vacation v (NOLOCK)
                ON vp.Person = v.Person
               AND vp.Company = v.Company
               AND vp.Line = v.Line
            INNER JOIN PR_Employee e (NOLOCK)
                ON vp.Person = e.Person
               AND vp.Company = e.Company
            INNER JOIN SY_Person sp (NOLOCK)
                ON vp.Person = sp.Person
            INNER JOIN PR_PayRollType pt (NOLOCK)
                ON e.PayRollType = pt.PayRollType
            LEFT JOIN PR_Position pos (NOLOCK)
                ON e.Position = pos.Position
        WHERE @incluir_pagados = 'Y'
          AND vp.Company = @cia
          AND vp.VacationType = 'D'
          AND e.PayRollType = @payrolltype
          AND (@person = '0' OR e.Person = @person)
          AND (@period = '0' OR LEFT(vp.PRPeriod, 6) = LEFT(@period, 6))
          AND e.Status = 'N'
          /* Solo si no hay utilización equivalente (mismo periodo + mismas fechas). */
          AND NOT EXISTS (
              SELECT 1
              FROM PR_VacationDetail vd2 (NOLOCK)
              WHERE vd2.Company = vp.Company
                AND vd2.Person = vp.Person
                AND LEFT(vd2.PRPeriod, 6) = LEFT(vp.PRPeriod, 6)
                AND vd2.DateBegin = vp.DateBegin
                AND vd2.DateEnd = vp.DateEnd
          )
    )
    SELECT
        prperiod,
        person,
        name,
        datebegin,
        dateend,
        days,
        controlyear,
        documentnumber,
        cargo,
        origen
    FROM detalle
    ORDER BY name, person, datebegin, origen;
END
GO
