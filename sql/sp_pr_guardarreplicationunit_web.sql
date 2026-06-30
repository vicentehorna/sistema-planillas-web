/*
    Alta / edición de SY_ReplicationUnit — maestro web Unidad.

    @modo: I = nuevo (ReplicationUnit lo ingresa el usuario, máx. 3 caracteres en mayúsculas),
           U = actualizar registro existente (no modifica ReplicationUnit).

    Description se guarda como los primeros 40 caracteres de name.

    Usado por: POST /api/unidades/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarreplicationunit_web]
    @modo               CHAR(1),
    @replicationunit    VARCHAR(4),
    @name               VARCHAR(255),
    @xlastuser          VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @replicationunit = UPPER(LTRIM(RTRIM(ISNULL(@replicationunit, ''))));
    SET @name = LTRIM(RTRIM(ISNULL(@name, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @replicationunit = ''
    BEGIN
        RAISERROR('Indique el código de unidad.', 16, 1);
        RETURN;
    END;

    IF LEN(@replicationunit) > 3
    BEGIN
        RAISERROR('El código de unidad debe tener como máximo 3 caracteres.', 16, 1);
        RETURN;
    END;

    IF @name = ''
    BEGIN
        RAISERROR('Indique el nombre de la unidad.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM SY_ReplicationUnit (NOLOCK)
            WHERE ReplicationUnit = @replicationunit
        )
        BEGIN
            RAISERROR('Ya existe una unidad con el mismo código.', 16, 1);
            RETURN;
        END;

        INSERT INTO SY_ReplicationUnit (
            ReplicationUnit,
            name,
            Description,
            Status,
            XLastUser,
            XLastDate
        )
        VALUES (
            @replicationunit,
            @name,
            LEFT(@name, 40),
            'A',
            @xlastuser,
            GETDATE()
        );

        SELECT
            @replicationunit AS replicationunit,
            'Unidad registrada correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM SY_ReplicationUnit (NOLOCK)
        WHERE ReplicationUnit = @replicationunit
    )
    BEGIN
        RAISERROR('No se encontró la unidad a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE SY_ReplicationUnit
    SET name = @name,
        Description = LEFT(@name, 40),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE ReplicationUnit = @replicationunit;

    SELECT
        @replicationunit AS replicationunit,
        'Unidad actualizada correctamente.' AS mensaje;
END
GO
