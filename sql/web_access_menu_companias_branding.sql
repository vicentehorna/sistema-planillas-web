/*
    Alta de menú Logo y Firma (Configuración → Generales).
    Permiso: perfiles ADMIN / FlagAdmin y perfiles RRHH*.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'companias_branding')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'companias_branding',
        'Logo y Firma',
        'generales',
        145,
        'companias_branding_page',
        '/companias-branding',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Logo y Firma',
        ParentCode = 'generales',
        SortOrder = 145,
        Endpoint = 'companias_branding_page',
        RoutePrefix = '/companias-branding',
        Status = 'A'
    WHERE MenuCode = 'companias_branding';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'companias_branding'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (
        P.FlagAdmin = 'Y'
     OR P.ProfileCode = 'ADMIN'
     OR P.ProfileCode LIKE 'RRHH%'
     OR UPPER(ISNULL(P.Name, '')) LIKE '%RRHH%'
  )
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'companias_branding'
  );
GO
