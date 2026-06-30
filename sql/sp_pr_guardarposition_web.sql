/*
    Alta / edición de PR_Position — maestro web Cargos.

    @modo: I = nuevo (genera Position con sp_pr_genera_correlativo_web / PR_POSITION),
           U = actualizar registro existente.

    Usado por: POST /api/cargos/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarposition_web]
    @modo       CHAR(1),
    @company    VARCHAR(4),
    @position   VARCHAR(20) = NULL,
    @name       VARCHAR(255),
    @xlastuser  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @position_nuevo  VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @position = NULLIF(LTRIM(RTRIM(ISNULL(@position, ''))), '');
    SET @name = LTRIM(RTRIM(ISNULL(@name, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @name = ''
    BEGIN
        RAISERROR('Indique el nombre del cargo.', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @position IS NULL
    BEGIN
        RAISERROR('Indique el código de cargo a actualizar.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM PR_Position (NOLOCK)
            WHERE Company = @company
              AND LTRIM(RTRIM(ISNULL(name, ''))) = @name
        )
        BEGIN
            RAISERROR('Ya existe un cargo con el mismo nombre para la compañía.', 16, 1);
            RETURN;
        END;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'PR_POSITION',
            @xlastuser = @xlastuser;

        SELECT @position_nuevo = id_generado FROM @tabla_id;

        IF @position_nuevo IS NULL OR LTRIM(RTRIM(@position_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo del cargo.', 16, 1);
            RETURN;
        END;

        INSERT INTO PR_Position (
            Position,
            name,
            Description,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate
        )
        VALUES (
            @position_nuevo,
            @name,
            LEFT(@name, 50),
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE()
        );

        SELECT
            @position_nuevo AS position,
            'Cargo registrado correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Position (NOLOCK)
        WHERE Company = @company
          AND Position = @position
    )
    BEGIN
        RAISERROR('No se encontró el cargo a actualizar.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Position (NOLOCK)
        WHERE Company = @company
          AND LTRIM(RTRIM(ISNULL(name, ''))) = @name
          AND Position <> @position
    )
    BEGIN
        RAISERROR('Ya existe otro cargo con el mismo nombre para la compañía.', 16, 1);
        RETURN;
    END;

    UPDATE PR_Position
    SET name = @name,
        Description = LEFT(@name, 50),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND Position = @position;

    SELECT
        @position AS position,
        'Cargo actualizado correctamente.' AS mensaje;
END
GO
