/*
    Alta de menú Empresas (Configuración → Generales, primera opción).
    Permiso: perfiles ADMIN / FlagAdmin.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'empresas')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'empresas',
        'Empresas',
        'generales',
        105,
        'empresas_page',
        '/empresas',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Empresas',
        ParentCode = 'generales',
        SortOrder = 105,
        Endpoint = 'empresas_page',
        RoutePrefix = '/empresas',
        Status = 'A'
    WHERE MenuCode = 'empresas';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'empresas'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (
        P.FlagAdmin = 'Y'
     OR P.ProfileCode = 'ADMIN'
  )
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'empresas'
  );
GO
