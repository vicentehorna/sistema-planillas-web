/*
    Elimina cabecera y detalle de tareo.
    Usado por: POST /api/tareo/registro/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_tareo_web]
    @tareoheader VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @tareoheader = LTRIM(RTRIM(ISNULL(@tareoheader, '')));

    IF @tareoheader = ''
    BEGIN
        RAISERROR('Indique el tareo.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM PR_TareoHeader (NOLOCK) WHERE TareoHeader = @tareoheader)
    BEGIN
        RAISERROR('El tareo no existe.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM PR_REGISTERHOUR WHERE tareoheader = @tareoheader;
        DELETE FROM PR_TareoGeneral WHERE TareoHeader = @tareoheader;
        DELETE FROM PR_TareoHeader WHERE TareoHeader = @tareoheader;

        COMMIT TRANSACTION;

        SELECT @tareoheader AS tareoheader, 'Tareo eliminado.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
