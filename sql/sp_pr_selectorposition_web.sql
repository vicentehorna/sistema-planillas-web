/*
    Selector de cargos (PR_Position) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorposition_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(p.Position)) AS id,
        LTRIM(RTRIM(ISNULL(NULLIF(p.Name, ''), p.Description))) AS text
    FROM PR_Position p (NOLOCK)
    WHERE p.Company = @cia
      AND UPPER(ISNULL(p.Status, 'A')) <> 'I'
    ORDER BY text ASC, id ASC;
END
GO
