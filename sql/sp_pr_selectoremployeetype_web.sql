/*
    Selector de tipo de trabajador (PR_EmployeeType) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectoremployeetype_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(t.EmployeeType)) AS id,
        LTRIM(RTRIM(ISNULL(t.Description, t.EmployeeType))) AS text
    FROM PR_EmployeeType t (NOLOCK)
    WHERE t.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
