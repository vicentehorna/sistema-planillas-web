/*
    Alta de menú Control de Préstamos (grupo Préstamos bajo Procesos) + permiso ADMIN.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'control_prestamos')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'control_prestamos',
        'Control de Prestamos',
        'prestamos',
        1210,
        'control_prestamos_page',
        '/control-prestamos',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Control de Prestamos',
        ParentCode = 'prestamos',
        SortOrder = 1210,
        Endpoint = 'control_prestamos_page',
        RoutePrefix = '/control-prestamos',
        Status = 'A'
    WHERE MenuCode = 'control_prestamos';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'control_prestamos'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'control_prestamos'
  );
GO
