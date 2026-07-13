/*
    Listado de asientos/vouchers de planilla (AC_Voucher).
    Solo Application = 'PR' (SISTEMA DE PLANILLAS).
    Filtros: compañía, periodo (YYYYMM exacto), estado (A = Aprobado por defecto).

    Usado por: POST /api/asientos/interfaz/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_asientos_interfaz_web]
    @company   VARCHAR(4),
    @period    VARCHAR(6) = NULL,
    @status    VARCHAR(1) = 'A',
    @busqueda  VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = NULLIF(LTRIM(RTRIM(ISNULL(@period, ''))), '');
    SET @status = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@status, '')))), '');
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    /* Si llega yyyy-mm, normalizar a yyyymm */
    IF @period IS NOT NULL AND LEN(@period) = 7 AND SUBSTRING(@period, 5, 1) = '-'
        SET @period = LEFT(@period, 4) + RIGHT(@period, 2);

    SELECT
        LTRIM(RTRIM(v.Voucher)) AS voucher,
        LTRIM(RTRIM(ISNULL(v.VoucherNo, ''))) AS voucherno,
        LTRIM(RTRIM(ISNULL(v.Company, ''))) AS company,
        LTRIM(RTRIM(ISNULL(v.Period, ''))) AS period,
        CASE
            WHEN LEN(LTRIM(RTRIM(ISNULL(v.Period, '')))) = 6
                THEN LEFT(v.Period, 4) + '-' + RIGHT(v.Period, 2)
            ELSE LTRIM(RTRIM(ISNULL(v.Period, '')))
        END AS period_fmt,
        LTRIM(RTRIM(ISNULL(v.BusinessUnit, ''))) AS businessunit,
        v.VoucherDate AS voucherdate,
        LTRIM(RTRIM(ISNULL(v.Title, ''))) AS title,
        CASE
            WHEN ISNULL(v.ACCurrency, 'LO') = 'LO' THEN ISNULL(v.TotalCreditLo, 0)
            ELSE ISNULL(v.TotalCreditEx, 0)
        END AS importe,
        LTRIM(RTRIM(ISNULL(v.Status, ''))) AS status,
        CASE LTRIM(RTRIM(ISNULL(v.Status, '')))
            WHEN 'A' THEN 'Aprobado'
            WHEN 'N' THEN 'No aprobado'
            WHEN 'V' THEN 'Anulado'
            ELSE LTRIM(RTRIM(ISNULL(v.Status, '')))
        END AS status_desc,
        LTRIM(RTRIM(ISNULL(v.EntryUser, ''))) AS entryuser,
        v.EntryDate AS entrydate,
        LTRIM(RTRIM(ISNULL(v.Application, ''))) AS application
    FROM AC_Voucher v (NOLOCK)
    WHERE v.Company = @company
      AND v.Application = 'PR'
      AND (@period IS NULL OR v.Period = @period)
      AND (@status IS NULL OR v.Status = @status)
      AND (
            @busqueda IS NULL
         OR ISNULL(v.VoucherNo, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(v.Title, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(v.EntryUser, '') LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        v.Period ASC,
        v.VoucherNo ASC;
END
GO
