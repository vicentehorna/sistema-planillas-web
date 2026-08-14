/*
    Selector de centros de costo (AC_CostCenter) por compañía.
    Texto: Abbrev - Description (o Name), para que se vea claro en combos.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorcostcenter_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(cc.CostCenter)) AS id,
        LTRIM(RTRIM(
            CASE
                WHEN LTRIM(RTRIM(ISNULL(cc.Abbrev, ''))) <> ''
                 AND LTRIM(RTRIM(ISNULL(cc.Description, ''))) <> ''
                    THEN LTRIM(RTRIM(cc.Abbrev)) + ' - ' + LTRIM(RTRIM(cc.Description))
                WHEN LTRIM(RTRIM(ISNULL(cc.Abbrev, ''))) <> ''
                 AND LTRIM(RTRIM(ISNULL(cc.Name, ''))) <> ''
                    THEN LTRIM(RTRIM(cc.Abbrev)) + ' - ' + LTRIM(RTRIM(cc.Name))
                WHEN LTRIM(RTRIM(ISNULL(cc.Description, ''))) <> ''
                    THEN LTRIM(RTRIM(cc.Description))
                WHEN LTRIM(RTRIM(ISNULL(cc.Name, ''))) <> ''
                    THEN LTRIM(RTRIM(cc.Name))
                WHEN LTRIM(RTRIM(ISNULL(cc.Abbrev, ''))) <> ''
                    THEN LTRIM(RTRIM(cc.Abbrev))
                ELSE LTRIM(RTRIM(cc.CostCenter))
            END
        )) AS text
    FROM AC_CostCenter cc (NOLOCK)
    WHERE LTRIM(RTRIM(cc.Company)) = @cia
      AND UPPER(LTRIM(RTRIM(ISNULL(cc.Status, 'A')))) IN ('A', '')
    ORDER BY text ASC, id ASC;
END
GO
