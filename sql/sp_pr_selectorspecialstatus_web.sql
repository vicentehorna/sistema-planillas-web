/*
    Selector de situación especial (PR_SpecialStatus) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorspecialstatus_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(s.SpecialStatus)) AS id,
        LTRIM(RTRIM(ISNULL(s.Description, s.SpecialStatus))) AS text
    FROM PR_SpecialStatus s (NOLOCK)
    WHERE s.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
