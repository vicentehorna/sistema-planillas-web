/*
    Detalle de cargo para edición (maestro Cargos — PR_Position).
    Usado por: POST /api/cargos/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerposition_web]
    @company   VARCHAR(4),
    @position  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @position = LTRIM(RTRIM(ISNULL(@position, '')));

    SELECT
        p.Position AS position,
        p.Company AS company,
        LTRIM(RTRIM(ISNULL(p.name, ''))) AS name,
        CASE WHEN UPPER(ISNULL(p.Status, 'A')) = 'I' THEN 'I' ELSE 'A' END AS status,
        p.XLastUser AS xlastuser,
        p.XLastDate AS xlastdate
    FROM PR_Position p (NOLOCK)
    WHERE p.Company = @company
      AND p.Position = @position;
END
GO
