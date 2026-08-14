/*
    Maestro Tipo de Día (Tareo) — alta / edición PR_TIPODIA.
    Usado por: POST /api/tareo/tipos-dia/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardar_tipodia_web]
    @modo      CHAR(1),
    @fila      INT = NULL,
    @codigo    VARCHAR(3),
    @nombre    VARCHAR(255),
    @horas     DECIMAL(18, 2) = 0,
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @fila_nueva INT;

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @codigo = LTRIM(RTRIM(ISNULL(@codigo, '')));
    SET @nombre = LTRIM(RTRIM(ISNULL(@nombre, '')));
    SET @horas = ISNULL(@horas, 0);
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido.', 16, 1);
        RETURN;
    END;

    IF @codigo = '' OR @nombre = ''
    BEGIN
        RAISERROR('Indique el codigo y el nombre del tipo de dia.', 16, 1);
        RETURN;
    END;

    IF LEN(@codigo) > 3
    BEGIN
        RAISERROR('El codigo no puede superar 3 caracteres.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_TIPODIA (NOLOCK)
        WHERE LTRIM(RTRIM(ISNULL(codigo, ''))) = @codigo
          AND (@modo = 'I' OR Fila <> @fila)
    )
    BEGIN
        RAISERROR('Ya existe un tipo de dia con el mismo codigo.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        INSERT INTO PR_TIPODIA (name, codigo, ValorDefecto, xlastuser, xlastdate)
        VALUES (@nombre, @codigo, @horas, @xlastuser, GETDATE());

        SET @fila_nueva = SCOPE_IDENTITY();

        SELECT
            @fila_nueva AS fila,
            N'Tipo de d' + NCHAR(237) + N'a registrado correctamente.' AS mensaje;
        RETURN;
    END;

    IF @fila IS NULL OR NOT EXISTS (
        SELECT 1 FROM PR_TIPODIA (NOLOCK) WHERE Fila = @fila
    )
    BEGIN
        RAISERROR('No se encontro el tipo de dia a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE PR_TIPODIA
    SET name = @nombre,
        codigo = @codigo,
        ValorDefecto = @horas,
        xlastuser = @xlastuser,
        xlastdate = GETDATE()
    WHERE Fila = @fila;

    SELECT
        @fila AS fila,
        N'Tipo de d' + NCHAR(237) + N'a actualizado correctamente.' AS mensaje;
END
GO
