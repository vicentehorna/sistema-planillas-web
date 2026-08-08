/*
    Datos para PDF Constancia de Goce Vacacional (DataWindow PowerBuilder).

    Parámetros:
      @cia, @payrolltype, @person, @fecha
      @line — opcional;  NULL o -1 = todos los detalles del trabajador en el YYYYMM.

    FECHA del memo = día anterior al primer DateBegin del goce filtrado.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_formatovacaciones_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20),
    @person      VARCHAR(20),
    @fecha       DATETIME,
    @line        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha IS NULL SET @fecha = GETDATE();

    DECLARE @yyyymm VARCHAR(6) = CONVERT(VARCHAR(6), @fecha, 112);

    ;WITH Det AS (
        SELECT
            vd.Person,
            vd.Line,
            vd.DateBegin,
            vd.DateEnd,
            vd.Days,
            v.ControlYear,
            vd.PRPeriod,
            ROW_NUMBER() OVER (ORDER BY vd.DateBegin, vd.Line) AS rn
        FROM PR_VacationDetail vd
            INNER JOIN PR_Vacation v (NOLOCK)
                ON vd.Person = v.Person
               AND vd.Company = v.Company
               AND vd.Line = v.Line
            INNER JOIN PR_Employee e (NOLOCK)
                ON vd.Person = e.Person
               AND vd.Company = e.Company
        WHERE vd.Company = @cia
          AND vd.Person = @person
          AND e.PayRollType = @payrolltype
          AND LEFT(vd.PRPeriod, 6) = @yyyymm
          AND (@line IS NULL OR @line < 0 OR vd.Line = @line)
    ),
    Primero AS (
        SELECT TOP 1 DateBegin, ControlYear, Days
        FROM Det
        ORDER BY rn
    ),
    Totales AS (
        SELECT
            SUM(Days) AS total_days,
            MIN(DateBegin) AS min_begin,
            MAX(DateEnd) AS max_end
        FROM Det
    )
    SELECT
        sc.Description AS company_name,
        sc.Ruc AS company_ruc,
        sc.Address AS company_address,
        sc.Representative AS representative,
        sc.Rep_Position AS rep_position,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS person_name,
        LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ISNULL(sp.Ruc, '')))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(NULLIF(pos.name, ''), ISNULL(pos.Description, '')))) AS cargo,
        d.Line AS line,
        d.DateBegin AS datebegin,
        d.DateEnd AS dateend,
        d.Days AS days,
        d.ControlYear AS controlyear,
        CAST(CASE
            WHEN ISNUMERIC(d.ControlYear) = 1 THEN CAST(d.ControlYear AS INT) + 1
            ELSE NULL
        END AS VARCHAR(4)) AS controlyear_end,
        t.total_days,
        -- FECHA del documento: día anterior al primer inicio de goce
        DAY(DATEADD(DAY, -1, p.DateBegin)) AS fecha_dia,
        CASE MONTH(DATEADD(DAY, -1, p.DateBegin))
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS fecha_mes,
        YEAR(DATEADD(DAY, -1, p.DateBegin)) AS fecha_anio,
        DAY(d.DateBegin) AS begin_dia,
        CASE MONTH(d.DateBegin)
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS begin_mes,
        YEAR(d.DateBegin) AS begin_anio,
        DAY(d.DateEnd) AS end_dia,
        CASE MONTH(d.DateEnd)
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS end_mes,
        YEAR(d.DateEnd) AS end_anio,
        p.ControlYear AS header_controlyear,
        CAST(CASE
            WHEN ISNUMERIC(p.ControlYear) = 1 THEN CAST(p.ControlYear AS INT) + 1
            ELSE NULL
        END AS VARCHAR(4)) AS header_controlyear_end,
        p.Days AS header_days
    FROM Det d
        CROSS JOIN Primero p
        CROSS JOIN Totales t
        INNER JOIN SY_Person sp ON sp.Person = d.Person
        INNER JOIN PR_Employee e ON e.Person = d.Person AND e.Company = @cia
        INNER JOIN SY_Company sc ON sc.Company = @cia
        LEFT JOIN PR_Position pos ON e.Position = pos.Position
    ORDER BY d.DateBegin, d.Line;
END
GO
