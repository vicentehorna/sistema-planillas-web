/*
    Listado de unidades de replicación (maestro Unidad — SY_ReplicationUnit).
    Tabla general, sin filtro por compañía.
    Usado por: POST /api/unidades/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarreplicationunit_web]
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        ru.ReplicationUnit AS replicationunit,
        LTRIM(RTRIM(ISNULL(ru.name, ''))) AS name,
        ru.XLastUser AS xlastuser,
        ru.XLastDate AS xlastdate
    FROM SY_ReplicationUnit ru (NOLOCK)
    WHERE (
            @busqueda IS NULL
         OR ru.ReplicationUnit LIKE '%' + @busqueda + '%'
         OR ru.name LIKE '%' + @busqueda + '%'
         OR ru.Description LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        ru.ReplicationUnit ASC;
END
GO
