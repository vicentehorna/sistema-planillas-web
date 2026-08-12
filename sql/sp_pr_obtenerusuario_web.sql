/*
    Detalle de usuario + perfiles asignados (SY_UserProfile).
    Devuelve 2 result sets:
      1) cabecera usuario
      2) perfiles del usuario (Profile, Description)

    Usado por: POST /api/usuarios/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerusuario_web]
    @userid VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));
    IF @userid = ''
    BEGIN
        RAISERROR('Indique el usuario.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM SY_User (NOLOCK) WHERE UserID = @userid)
    BEGIN
        RAISERROR('El usuario no existe.', 16, 1);
        RETURN;
    END;

    SELECT
        u.UserID AS userid,
        ISNULL(u.PasswordWeb, '') AS passwordweb,
        ISNULL(p.Person, '') AS person,
        ISNULL(p.Name, '') AS nombre
    FROM SY_User u (NOLOCK)
    OUTER APPLY (
        SELECT TOP 1 sp.Person, sp.Name
        FROM SY_Person sp (NOLOCK)
        WHERE sp.UserID = u.UserID
        ORDER BY sp.Person
    ) p
    WHERE u.UserID = @userid;

    SELECT
        up.Profile AS profile,
        ISNULL(pr.Description, up.Profile) AS description
    FROM SY_UserProfile up (NOLOCK)
    LEFT JOIN SY_Profile pr (NOLOCK)
        ON pr.Profile = up.Profile
    WHERE up.UserID = @userid
    ORDER BY up.Profile;
END
GO
