/*
    Selector de compañías activas (SY_Company).
    Usado por: GET /api/selectores/companias (PLAME, reportes, trabajadores, etc.).

    id: Company
    text: description
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorcompanias_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Company,
        description
    FROM SY_Company (NOLOCK)
    WHERE UPPER(LTRIM(RTRIM(ISNULL([status], '')))) = 'A'
    ORDER BY Company ASC;
END
GO
