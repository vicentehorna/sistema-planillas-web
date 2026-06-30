/*
    Listado de cargos por compañía (maestro Cargos — PR_Position).
    Usado por: POST /api/cargos/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarposition_web]
    @company VARCHAR(4),
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        p.Position AS position,
        LTRIM(RTRIM(ISNULL(p.name, ''))) AS name,
        p.XLastUser AS xlastuser,
        p.XLastDate AS xlastdate
    FROM PR_Position p (NOLOCK)
    WHERE p.Company = @company
      AND (
            @busqueda IS NULL
         OR p.name LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        p.name ASC,
        p.Position ASC;
END
GO
