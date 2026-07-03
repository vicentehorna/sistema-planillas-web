/*
    Selector de motivo de cese (PR_CeaseReason) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorceasereason_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(cr.CeaseReason)) AS id,
        LTRIM(RTRIM(ISNULL(cr.Description, cr.CeaseReason))) AS text
    FROM PR_CeaseReason cr (NOLOCK)
    WHERE cr.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
