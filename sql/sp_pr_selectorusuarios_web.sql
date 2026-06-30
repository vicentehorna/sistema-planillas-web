/*
    Selector de usuarios del sistema (SY_User).
    Usado por: GET /api/selectores/usuarios
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorusuarios_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.UserID AS id,
        u.UserID AS text
    FROM SY_User u (NOLOCK)
    ORDER BY u.UserID ASC;
END
GO
