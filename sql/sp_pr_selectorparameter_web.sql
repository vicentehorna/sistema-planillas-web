/*
    Selector de parámetros de planilla (detalle tipo P).
    Usado por: GET /api/selectores/parameters
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorparameter_web]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));

    SELECT
        p.Parameter AS id,
        p.ShortName AS text
    FROM PR_Parameter p (NOLOCK)
    WHERE p.Company = @company
    ORDER BY p.ShortName ASC;
END
GO
