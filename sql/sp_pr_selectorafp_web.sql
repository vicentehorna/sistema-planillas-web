/*
    Selector AFP por compañía.

    Usado por: GET /api/selectores/afp?cia=...
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorafp_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(A.AFP)) AS id,
        LTRIM(RTRIM(ISNULL(A.Description, A.AFP))) AS text
    FROM PR_AFP A (NOLOCK)
    WHERE
        @cia = ''
        OR LTRIM(RTRIM(ISNULL(A.Company, ''))) = ''
        OR LTRIM(RTRIM(A.Company)) = @cia
    ORDER BY text ASC;
END
GO
