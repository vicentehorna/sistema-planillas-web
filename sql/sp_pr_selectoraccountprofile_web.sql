/*
    Selector de perfil contable (PR_AccountProfile) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectoraccountprofile_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(a.AccountProfile)) AS id,
        LTRIM(RTRIM(ISNULL(a.Description, a.AccountProfile))) AS text
    FROM PR_AccountProfile a (NOLOCK)
    WHERE a.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
