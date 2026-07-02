/*
    Selector de centros de costo (AC_CostCenter) por compañía.
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
            ISNULL(cc.Name, '') +
            CASE
                WHEN LTRIM(RTRIM(ISNULL(cc.Name, ''))) = '' THEN LTRIM(RTRIM(cc.CostCenter))
                ELSE ''
            END
        )) AS text
    FROM AC_CostCenter cc (NOLOCK)
    WHERE cc.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
