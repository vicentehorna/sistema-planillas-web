/*
    Reporte Resumen de Tareos (hm_ultra).
    Fuente: PR_REGISTERHOUR (generado al guardar/procesar tareo).

    Filtros web:
      @company     — obligatorio
      @payrolltype — vacío = todas
      @prperiod    — formato 20260808; se toma el mes (YYYYMM)
      @costcenter  — unidad (PR_TareoHeader.costcenter); vacío = todas

    Mejoras vs sp_pr_reportetareoresumen legado:
      - Parámetros simplificados (periodo en lugar de rango de fechas)
      - Unidad por cabecera de tareo (CostCenter en REGISTERHOUR suele ir NULL)
      - Rango de fechas sargable (RegisterDate >= / <)
      - Sin filtros no usados (persona, tipodia, sede)
      - RTRIM de RegisterType por compatibilidad

    Usado por: POST /api/tareo/reporte-resumen
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportetareoresumen_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20) = NULL,
    @prperiod    VARCHAR(20),
    @costcenter  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ym CHAR(6);
    DECLARE @fecha_ini DATE;
    DECLARE @fecha_fin DATE;
    DECLARE @fecha_fin_excl DATE;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = NULLIF(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), '');
    SET @prperiod = LTRIM(RTRIM(ISNULL(@prperiod, '')));
    SET @costcenter = NULLIF(LTRIM(RTRIM(ISNULL(@costcenter, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF LEN(@prperiod) < 6 OR ISNUMERIC(LEFT(@prperiod, 6)) = 0
    BEGIN
        RAISERROR('Indique un periodo válido (ej. 20260808).', 16, 1);
        RETURN;
    END;

    SET @ym = LEFT(@prperiod, 6);
    IF ISDATE(@ym + '01') = 0
    BEGIN
        RAISERROR('El periodo no corresponde a un mes válido.', 16, 1);
        RETURN;
    END;

    SET @fecha_ini = CONVERT(DATE, @ym + '01', 112);
    SET @fecha_fin = EOMONTH(@fecha_ini);
    SET @fecha_fin_excl = DATEADD(DAY, 1, @fecha_fin);

    SELECT
        T.Person AS person,
        T.Name AS name,
        CONVERT(VARCHAR(10), T.entrydate, 23) AS entrydate,
        CONVERT(VARCHAR(10), T.CeaseDate, 23) AS ceasedate,
        T.hourday,
        T.extrahour25,
        T.extrahour35,
        T.extrahour100,
        T.faltas,
        T.vacaciones,
        T.medicos,
        T.feriadotrab,
        T.desctrab,
        T.gocefer,
        T.lcg,
        T.lsg,
        T.lma,
        T.lpa,
        T.susp,
        T.subsidio,
        T.descansos,
        T.sinmarca,
        CASE
            WHEN T.CeaseDate IS NOT NULL THEN
                CASE WHEN DATEPART(DAY, T.CeaseDate) = 31 THEN 30 ELSE DATEPART(DAY, T.CeaseDate) END
                - (CASE
                       WHEN CONVERT(VARCHAR(6), T.entrydate, 112) = CONVERT(VARCHAR(6), T.CeaseDate, 112)
                       THEN DATEPART(DAY, T.entrydate) - 1
                       ELSE 0
                   END)
                - (ISNULL(T.lma, 0) + ISNULL(T.vacaciones, 0) + ISNULL(T.faltas, 0)
                   + ISNULL(T.lsg, 0) + ISNULL(T.lcg, 0) + ISNULL(T.medicos, 0) + ISNULL(T.susp, 0))
            ELSE
                (CASE
                    WHEN T.entrydate IS NOT NULL
                     AND CONVERT(VARCHAR(6), T.entrydate, 112) = @ym THEN
                        (CASE
                            WHEN MONTH(T.entrydate) IN (1, 3, 5, 7, 8, 10, 12)
                             AND DAY(T.entrydate) <> 1 THEN 31
                            ELSE 30
                         END) - DATEPART(DAY, T.entrydate) + 1
                    ELSE 30
                 END)
                - (ISNULL(T.lma, 0) + ISNULL(T.vacaciones, 0) + ISNULL(T.faltas, 0)
                   + ISNULL(T.lsg, 0) + ISNULL(T.lcg, 0) + ISNULL(T.medicos, 0) + ISNULL(T.susp, 0))
        END AS diastrab
    FROM (
        SELECT
            b.Person,
            b.Name,
            ISNULL(d.ReEntryDate, d.EntryDate) AS entrydate,
            d.CeaseDate,
            SUM(ISNULL(a.hourday, 0)) AS hourday,
            SUM(ISNULL(a.extrahour25, 0)) AS extrahour25,
            SUM(ISNULL(a.extrahour35, 0)) AS extrahour35,
            SUM(ISNULL(a.extrahour100, 0)) AS extrahour100,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'F' THEN 1 ELSE 0 END) AS faltas,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'V' THEN 1 ELSE 0 END) AS vacaciones,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'DM' THEN 1 ELSE 0 END) AS medicos,
            SUM(CASE WHEN RTRIM(a.RegisterType) IN ('FTD', 'FTN') THEN 1 ELSE 0 END) AS feriadotrab,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'DST' THEN 1 ELSE 0 END) AS desctrab,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'GF' THEN 1 ELSE 0 END) AS gocefer,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'LCG' THEN 1 ELSE 0 END) AS lcg,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'LSG' THEN 1 ELSE 0 END) AS lsg,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'LMA' THEN 1 ELSE 0 END) AS lma,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'LPA' THEN 1 ELSE 0 END) AS lpa,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'S' THEN 1 ELSE 0 END) AS susp,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'SUB' THEN 1 ELSE 0 END) AS subsidio,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'DS' THEN 1 ELSE 0 END) AS descansos,
            SUM(CASE WHEN RTRIM(a.RegisterType) = 'X' THEN 1 ELSE 0 END) AS sinmarca
        FROM PR_REGISTERHOUR a (NOLOCK)
        INNER JOIN SY_Person b (NOLOCK)
            ON a.Person = b.Person
        INNER JOIN PR_Employee d (NOLOCK)
            ON a.Person = d.Person
           AND d.Company = @company
        LEFT JOIN PR_TareoHeader H (NOLOCK)
            ON H.TareoHeader = a.tareoheader
        WHERE a.Company = @company
          AND a.RegisterDate >= @fecha_ini
          AND a.RegisterDate < @fecha_fin_excl
          AND (@payrolltype IS NULL OR a.Payrolltype = @payrolltype)
          AND (
                @costcenter IS NULL
             OR H.costcenter = @costcenter
             OR a.CostCenter = @costcenter
          )
        GROUP BY
            b.Person,
            b.Name,
            ISNULL(d.ReEntryDate, d.EntryDate),
            d.CeaseDate
    ) T
    ORDER BY T.Name, T.Person;
END
GO
