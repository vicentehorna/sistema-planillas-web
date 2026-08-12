/*
    Selector de perfiles SY_Profile para filtro / asignación de usuarios.

    Usado por: GET /api/selectores/perfiles-sy  y maestro Usuarios.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperfiles_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.Profile AS id,
        ISNULL(NULLIF(LTRIM(RTRIM(p.Description)), ''), p.Profile) AS text
    FROM SY_Profile p (NOLOCK)
    WHERE ISNULL(p.Status, 'A') = 'A'
       OR p.Status IS NULL
       OR LTRIM(RTRIM(p.Status)) = ''
    ORDER BY text, p.Profile;
END
GO
