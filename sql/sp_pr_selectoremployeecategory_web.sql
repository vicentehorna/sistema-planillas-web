/*
    Selector de categoría de trabajador (PR_EmployeeCategory) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectoremployeecategory_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(c.EmployeeCategory)) AS id,
        LTRIM(RTRIM(ISNULL(c.Description, c.EmployeeCategory))) AS text
    FROM PR_EmployeeCategory c (NOLOCK)
    WHERE c.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
