/*
    Alta de menú Usuarios (Tablas) + permiso a perfiles ADMIN.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'usuarios')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'usuarios',
        'Usuarios',
        'tablas',
        260,
        'usuarios_page',
        '/usuarios',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Usuarios',
        ParentCode = 'tablas',
        SortOrder = 260,
        Endpoint = 'usuarios_page',
        RoutePrefix = '/usuarios',
        Status = 'A'
    WHERE MenuCode = 'usuarios';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'usuarios'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'usuarios'
  );
GO
