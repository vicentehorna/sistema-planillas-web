/*
    Cambia PasswordWeb de SY_User (login web).
    Usado por: POST /cambiar-password (login).

    Retorna: resultado ('OK'/'KO'), Mensaje
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_CambiarPassword_web]
    @userid      VARCHAR(20),
    @clave_ant   VARCHAR(20),
    @clave_nueva VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @uid VARCHAR(20) = LTRIM(RTRIM(ISNULL(@userid, '')));
    DECLARE @ant VARCHAR(20) = ISNULL(@clave_ant, '');
    DECLARE @nueva VARCHAR(20) = ISNULL(@clave_nueva, '');
    DECLARE @actual VARCHAR(20);

    IF @uid = ''
    BEGIN
        SELECT 'KO' AS resultado, 'Usuario no indicado.' AS Mensaje;
        RETURN;
    END;

    IF @nueva = ''
    BEGIN
        SELECT 'KO' AS resultado, 'Debe indicar la nueva contraseña.' AS Mensaje;
        RETURN;
    END;

    IF @nueva = @ant
    BEGIN
        SELECT 'KO' AS resultado, 'La nueva contraseña debe ser distinta a la anterior.' AS Mensaje;
        RETURN;
    END;

    SELECT @actual = PasswordWeb
    FROM SY_User (NOLOCK)
    WHERE UserID = @uid;

    IF @actual IS NULL
    BEGIN
        SELECT 'KO' AS resultado, 'Usuario no encontrado.' AS Mensaje;
        RETURN;
    END;

    IF ISNULL(@actual, '') <> @ant
    BEGIN
        SELECT 'KO' AS resultado, 'La contraseña anterior no es correcta.' AS Mensaje;
        RETURN;
    END;

    UPDATE SY_User
    SET PasswordWeb = @nueva,
        XLastUser = @uid,
        XLastDate = GETDATE()
    WHERE UserID = @uid;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 'KO' AS resultado, 'No se pudo actualizar la contraseña.' AS Mensaje;
        RETURN;
    END;

    SELECT 'OK' AS resultado, 'Contraseña actualizada correctamente.' AS Mensaje;
END
GO
