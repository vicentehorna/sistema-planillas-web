/*
    Selector de ocupación (PR_Ocupation) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorocupation_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(o.Ocupation)) AS id,
        LTRIM(RTRIM(ISNULL(o.Description, o.Ocupation))) AS text
    FROM PR_Ocupation o (NOLOCK)
    WHERE o.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
