/*
    Selector de cargos (PR_Position) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorposition_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    ;WITH catalogo AS (
        SELECT
            LTRIM(RTRIM(p.Position)) AS id,
            LTRIM(RTRIM(ISNULL(NULLIF(p.Name, ''), p.Description))) AS text
        FROM PR_Position p (NOLOCK)
        WHERE p.Company = @cia
    ),
    en_uso AS (
        /* Cargos ya asignados a trabajadores de la compañía (p. ej. legacy S172 en hm_garc). */
        SELECT DISTINCT
            LTRIM(RTRIM(p.Position)) AS id,
            LTRIM(RTRIM(ISNULL(NULLIF(p.Name, ''), p.Description))) AS text
        FROM PR_Employee e (NOLOCK)
            INNER JOIN PR_Position p (NOLOCK)
                ON p.Position = e.Position
        WHERE e.Company = @cia
          AND NULLIF(LTRIM(RTRIM(e.Position)), '') IS NOT NULL
    )
    SELECT id, text
    FROM (
        SELECT id, text FROM catalogo
        UNION
        SELECT id, text FROM en_uso
    ) x
    ORDER BY text ASC, id ASC;
END
GO
