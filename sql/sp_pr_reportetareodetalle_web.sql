/*
    Reporte Detalle de Tareos (hm_ultra) — día a día.
    Fuente: PR_REGISTERHOUR + PR_TIPODIA + AC_CostCenter + SY_ReplicationUnit.

    Filtros web:
      @company     — obligatorio
      @payrolltype — vacío = todas
      @prperiod    — formato 20260808; se toma el mes (YYYYMM)
      @costcenter  — unidad (PR_TareoHeader.costcenter / REGISTERHOUR.CostCenter); vacío = todas
      @person      — trabajador; vacío = todos
      @tipodia     — código PR_TIPODIA / RegisterType; vacío = todos

    Columnas:
      Código, Nombre, Fecha, Tipo Día, Cliente, Sede, Horas, HE 25, HE 35, H NOC

    Usado por: POST /api/tareo/reporte-detalle
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportetareodetalle_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20) = NULL,
    @prperiod    VARCHAR(20),
    @costcenter  VARCHAR(20) = NULL,
    @person      VARCHAR(20) = NULL,
    @tipodia     VARCHAR(10) = NULL
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
    SET @person = NULLIF(LTRIM(RTRIM(ISNULL(@person, ''))), '');
    SET @tipodia = NULLIF(LTRIM(RTRIM(ISNULL(@tipodia, ''))), '');

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
        b.Person AS person,
        b.Name AS name,
        CONVERT(VARCHAR(10), a.RegisterDate, 23) AS fecha,
        RTRIM(a.RegisterType) AS tipodia_codigo,
        ISNULL(NULLIF(RTRIM(td.name), ''), RTRIM(a.RegisterType)) AS tipodia,
        ISNULL(RTRIM(cc.Name), '') AS cliente,
        ISNULL(RTRIM(ru.Name), '') AS sede,
        ISNULL(a.hourday, 0) AS hourday,
        ISNULL(a.extrahour25, 0) AS extrahour25,
        ISNULL(a.extrahour35, 0) AS extrahour35,
        ISNULL(a.extrahour100, 0) AS extrahour100
    FROM PR_REGISTERHOUR a (NOLOCK)
    INNER JOIN SY_Person b (NOLOCK)
        ON a.Person = b.Person
    LEFT JOIN PR_TareoHeader H (NOLOCK)
        ON H.TareoHeader = a.tareoheader
    LEFT JOIN PR_TIPODIA td (NOLOCK)
        ON RTRIM(td.codigo) = RTRIM(a.RegisterType)
    LEFT JOIN AC_CostCenter cc (NOLOCK)
        ON cc.Company = a.Company
       AND cc.CostCenter = COALESCE(NULLIF(RTRIM(a.CostCenter), ''), H.costcenter)
    LEFT JOIN SY_ReplicationUnit ru (NOLOCK)
        ON ru.ReplicationUnit = COALESCE(
                NULLIF(RTRIM(a.ReplicationUnit), ''),
                cc.ReplicationUnit
           )
    WHERE a.Company = @company
      AND a.RegisterDate >= @fecha_ini
      AND a.RegisterDate < @fecha_fin_excl
      AND (@payrolltype IS NULL OR a.Payrolltype = @payrolltype)
      AND (
            @costcenter IS NULL
         OR H.costcenter = @costcenter
         OR a.CostCenter = @costcenter
      )
      AND (@person IS NULL OR a.Person = @person)
      AND (@tipodia IS NULL OR RTRIM(a.RegisterType) = @tipodia)
    ORDER BY b.Name, b.Person, a.RegisterDate;
END
GO
