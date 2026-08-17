/*
    Menú Tareo → Registro de Tareos (hm_ultra / Ultrasegur).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_registro')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_registro',
        'Registro de Tareos',
        'tareo',
        420,
        'tareo_registro_page',
        '/tareo/registro',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Registro de Tareos',
        ParentCode = 'tareo',
        SortOrder = 420,
        Endpoint = 'tareo_registro_page',
        RoutePrefix = '/tareo/registro',
        Status = 'A'
    WHERE MenuCode = 'tareo_registro';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_registro'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_registro'
  );
GO
