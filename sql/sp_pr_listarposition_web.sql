/*
    Listado de cargos por compañía (maestro Cargos — PR_Position).
    Usado por: POST /api/cargos/listado
    @status: A = Activos, I = Inactivos, T = Todos.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarposition_web]
    @company  VARCHAR(4),
    @busqueda VARCHAR(100) = NULL,
    @status   CHAR(1) = 'A'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');
    SET @status = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@status, 'A'))), 1));
    IF @status NOT IN ('A', 'I', 'T') SET @status = 'A';

    SELECT
        p.Position AS position,
        LTRIM(RTRIM(ISNULL(p.name, ''))) AS name,
        CASE WHEN UPPER(ISNULL(p.Status, 'A')) = 'I' THEN 'I' ELSE 'A' END AS status,
        p.XLastUser AS xlastuser,
        p.XLastDate AS xlastdate
    FROM PR_Position p (NOLOCK)
    WHERE p.Company = @company
      AND (
            @busqueda IS NULL
         OR p.name LIKE '%' + @busqueda + '%'
      )
      AND (
            @status = 'T'
         OR (@status = 'A' AND UPPER(ISNULL(p.Status, 'A')) <> 'I')
         OR (@status = 'I' AND UPPER(ISNULL(p.Status, 'A')) = 'I')
      )
    ORDER BY
        p.name ASC,
        p.Position ASC;
END
GO
