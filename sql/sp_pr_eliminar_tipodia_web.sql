/*
    Maestro Tipo de Día (Tareo) — eliminación PR_TIPODIA.
    Usado por: POST /api/tareo/tipos-dia/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_tipodia_web]
    @fila INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @fila IS NULL OR NOT EXISTS (
        SELECT 1 FROM PR_TIPODIA (NOLOCK) WHERE Fila = @fila
    )
    BEGIN
        RAISERROR('No se encontro el tipo de dia.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        DELETE FROM PR_TIPODIA WHERE Fila = @fila;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 547
            RAISERROR('No se puede eliminar: el tipo de dia esta en uso.', 16, 1);
        ELSE
        BEGIN
            DECLARE @error VARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR('%s', 16, 1, @error);
        END;
        RETURN;
    END CATCH;

    SELECT
        @fila AS fila,
        N'Tipo de d' + NCHAR(237) + N'a eliminado correctamente.' AS mensaje;
END
GO
