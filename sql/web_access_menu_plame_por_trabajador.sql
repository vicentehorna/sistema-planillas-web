/*
    Alta de menú PLAME por Trabajador + permiso a perfiles ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'plame_por_trabajador')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'plame_por_trabajador',
        'PLAME por Trabajador',
        'plame',
        535,
        'plame_por_trabajador_page',
        '/plame/por-trabajador',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'PLAME por Trabajador',
        ParentCode = 'plame',
        SortOrder = 535,
        Endpoint = 'plame_por_trabajador_page',
        RoutePrefix = '/plame/por-trabajador',
        Status = 'A'
    WHERE MenuCode = 'plame_por_trabajador';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'plame_por_trabajador'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'plame_por_trabajador'
  );
GO
