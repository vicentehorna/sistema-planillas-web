/*
    hm_divisa — selector de centros de costo para Distribución Porcentual.
    El código guardado en PR_DistribucionVoucher.codigo es AC_CostCenter.Abbrev.
    Usado por: GET /api/asientos/distribucion-porcentual/centros-costo
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selector_cc_abbrev_distribucion_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(cc.Abbrev)) AS id,
        LTRIM(RTRIM(
            CASE
                WHEN LTRIM(RTRIM(ISNULL(cc.Name, ''))) <> ''
                    THEN LTRIM(RTRIM(cc.Abbrev)) + ' — ' + LTRIM(RTRIM(cc.Name))
                WHEN LTRIM(RTRIM(ISNULL(cc.Description, ''))) <> ''
                    THEN LTRIM(RTRIM(cc.Abbrev)) + ' — ' + LTRIM(RTRIM(cc.Description))
                ELSE LTRIM(RTRIM(cc.Abbrev))
            END
        )) AS text
    FROM AC_CostCenter cc (NOLOCK)
    WHERE cc.Company = @cia
      AND LTRIM(RTRIM(ISNULL(cc.Abbrev, ''))) <> ''
      AND UPPER(LTRIM(RTRIM(ISNULL(cc.Status, 'A')))) IN ('A', '')
    ORDER BY text ASC, id ASC;
END
GO
