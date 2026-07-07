/*
    Listado de usuarios con perfil EMPWEB para maestro Usuarios por Empresa.
    Usado por: POST /api/usuarios-empresa/usuarios
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarusercompany_usuarios_web]
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        u.UserID AS userid,
        LTRIM(RTRIM(ISNULL(p.Name, ''))) AS nombre,
        ISNULL((
            SELECT COUNT(*)
            FROM SY_UserCompany uc (NOLOCK)
            WHERE uc.UserID = u.UserID
        ), 0) AS empresas_asignadas
    FROM SY_User u (NOLOCK)
        INNER JOIN SY_UserProfile up (NOLOCK)
            ON up.UserID = u.UserID
        INNER JOIN SY_Profile pr (NOLOCK)
            ON pr.Profile = up.Profile
           AND pr.Profile = 'EMPWEB'
        LEFT JOIN SY_Person p (NOLOCK)
            ON p.UserID = u.UserID
    WHERE (
            @busqueda IS NULL
         OR u.UserID LIKE '%' + @busqueda + '%'
         OR p.Name LIKE '%' + @busqueda + '%'
      )
    ORDER BY u.UserID ASC;
END
GO
