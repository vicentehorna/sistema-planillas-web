/*
    Elimina una configuración de concepto en PR_AccountProfileDetail.
    Clave: Detail + AccountProfile (+ Company).
    Usado por: POST /api/asientos/configurar-conceptos/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_accountprofiledetail_web]
    @company         VARCHAR(4),
    @detail          VARCHAR(20),
    @accountprofile  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @detail = LTRIM(RTRIM(ISNULL(@detail, '')));
    SET @accountprofile = LTRIM(RTRIM(ISNULL(@accountprofile, '')));

    IF @company = '' OR @detail = '' OR @accountprofile = ''
    BEGIN
        RAISERROR('Indique compañía, detalle y perfil contable.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_AccountProfileDetail (NOLOCK)
        WHERE Company = @company
          AND Detail = @detail
          AND AccountProfile = @accountprofile
    )
    BEGIN
        RAISERROR('La configuración no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_AccountProfileDetail
    WHERE Company = @company
      AND Detail = @detail
      AND AccountProfile = @accountprofile;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar la configuración.', 16, 1);
        RETURN;
    END;

    SELECT
        @detail AS detail,
        @accountprofile AS accountprofile,
        'Configuración eliminada correctamente.' AS mensaje;
END
GO
