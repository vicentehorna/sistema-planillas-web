/*
    Menú Tablas → Parámetros.
    Idempotente. Asigna a perfiles admin activos.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'parametros')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'parametros',
        'Parametros',
        'tablas',
        255,
        'parametros_page',
        '/parametros',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Parametros',
        ParentCode = 'tablas',
        SortOrder = 255,
        Endpoint = 'parametros_page',
        RoutePrefix = '/parametros',
        Status = 'A'
    WHERE MenuCode = 'parametros';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'parametros'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'parametros'
  );
GO
