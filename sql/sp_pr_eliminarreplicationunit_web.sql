/*
    Elimina una unidad de SY_ReplicationUnit si no está en uso.
    Usado por: POST /api/unidades/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarreplicationunit_web]
    @replicationunit VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @replicationunit = UPPER(LTRIM(RTRIM(ISNULL(@replicationunit, ''))));

    IF @replicationunit = ''
    BEGIN
        RAISERROR('Indique la unidad a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM SY_ReplicationUnit (NOLOCK)
        WHERE ReplicationUnit = @replicationunit
    )
    BEGIN
        RAISERROR('La unidad no existe.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM SY_Person (NOLOCK)
        WHERE ReplicationUnit = @replicationunit
    )
    BEGIN
        RAISERROR('No se puede eliminar: la unidad está asignada a personas.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM SY_ObjectSecuence (NOLOCK)
        WHERE ReplicationUnit = @replicationunit
    )
    BEGIN
        RAISERROR('No se puede eliminar: la unidad tiene correlativos configurados.', 16, 1);
        RETURN;
    END;

    DELETE FROM SY_ReplicationUnit
    WHERE ReplicationUnit = @replicationunit;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar la unidad.', 16, 1);
        RETURN;
    END;

    SELECT
        @replicationunit AS replicationunit,
        'Unidad eliminada correctamente.' AS mensaje;
END
GO
