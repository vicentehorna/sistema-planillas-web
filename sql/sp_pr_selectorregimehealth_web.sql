/*
    Selector de régimen de aseguramiento de salud (PR_RegimeHealth) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorregimehealth_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(R.RegimeHealth)) AS id,
        LTRIM(RTRIM(ISNULL(R.Description, R.RegimeHealth))) AS text
    FROM PR_RegimeHealth R (NOLOCK)
    WHERE
        @cia = ''
        OR LTRIM(RTRIM(ISNULL(R.Company, ''))) = ''
        OR LTRIM(RTRIM(R.Company)) = @cia
    ORDER BY text ASC;
END
GO
