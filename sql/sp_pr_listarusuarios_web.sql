/*
    Listado de usuarios SY_User (+ persona vinculada) para maestro web Usuarios.
    Filtros:
      @nombre  — busca en SY_Person.Name / apellidos / nombres (vacío = todos)
      @profile — perfil SY_UserProfile ('' o '0' = todos)

    Usado por: POST /api/usuarios/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarusuarios_web]
    @nombre  VARCHAR(100) = NULL,
    @profile VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @nombre = NULLIF(LTRIM(RTRIM(ISNULL(@nombre, ''))), '');
    SET @profile = NULLIF(LTRIM(RTRIM(ISNULL(@profile, ''))), '');
    IF @profile = '0' SET @profile = NULL;

    SELECT
        u.UserID AS userid,
        ISNULL(u.PasswordWeb, '') AS passwordweb,
        ISNULL(p.Person, '') AS person,
        ISNULL(p.Name, '') AS nombre
    FROM SY_User u (NOLOCK)
    OUTER APPLY (
        SELECT TOP 1
            sp.Person,
            sp.Name
        FROM SY_Person sp (NOLOCK)
        WHERE sp.UserID = u.UserID
        ORDER BY sp.Person
    ) p
    WHERE (
            @nombre IS NULL
         OR ISNULL(p.Name, '') LIKE '%' + @nombre + '%'
         OR ISNULL(p.Person, '') LIKE '%' + @nombre + '%'
         OR u.UserID LIKE '%' + @nombre + '%'
          )
      AND (
            @profile IS NULL
         OR EXISTS (
                SELECT 1
                FROM SY_UserProfile up (NOLOCK)
                WHERE up.UserID = u.UserID
                  AND up.Profile = @profile
            )
          )
    ORDER BY u.UserID ASC;
END
GO
