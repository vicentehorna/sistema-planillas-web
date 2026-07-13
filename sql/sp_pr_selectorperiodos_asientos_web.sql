/*
    Selector de periodos contables con vouchers de planilla (Application = PR).
    Usado por: GET /api/asientos/interfaz/periodos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_asientos_web]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));

    SELECT DISTINCT
        LTRIM(RTRIM(v.Period)) AS id,
        CASE
            WHEN LEN(LTRIM(RTRIM(v.Period))) = 6
                THEN LEFT(LTRIM(RTRIM(v.Period)), 4) + '-' + RIGHT(LTRIM(RTRIM(v.Period)), 2)
            ELSE LTRIM(RTRIM(v.Period))
        END AS text
    FROM AC_Voucher v (NOLOCK)
    WHERE v.Company = @company
      AND v.Application = 'PR'
      AND NULLIF(LTRIM(RTRIM(ISNULL(v.Period, ''))), '') IS NOT NULL
    ORDER BY id DESC;
END
GO
