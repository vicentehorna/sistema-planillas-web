/*
    Detalle de unidad de replicación para edición (maestro Unidad).
    Usado por: POST /api/unidades/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerreplicationunit_web]
    @replicationunit VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @replicationunit = UPPER(LTRIM(RTRIM(ISNULL(@replicationunit, ''))));

    SELECT
        ru.ReplicationUnit AS replicationunit,
        LTRIM(RTRIM(ISNULL(ru.name, ''))) AS name,
        ru.XLastUser AS xlastuser,
        ru.XLastDate AS xlastdate
    FROM SY_ReplicationUnit ru (NOLOCK)
    WHERE ru.ReplicationUnit = @replicationunit;
END
GO
