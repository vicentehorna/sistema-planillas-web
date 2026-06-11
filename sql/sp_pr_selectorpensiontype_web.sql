/*
    Selector de régimen de pensión (PR_PensionType) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpensiontype_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(P.PensionType)) AS id,
        LTRIM(RTRIM(ISNULL(P.Description, P.PensionType))) AS text
    FROM PR_PensionType P (NOLOCK)
    WHERE
        @cia = ''
        OR LTRIM(RTRIM(ISNULL(P.Company, ''))) = ''
        OR LTRIM(RTRIM(P.Company)) = @cia
    ORDER BY text ASC;
END
GO
