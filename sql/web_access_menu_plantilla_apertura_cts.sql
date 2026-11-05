/*
    Menú CTS → Plantilla Apertura (SOLO hm_alamo).
    Idempotente. Asigna a ADMIN y a perfiles con formato_cts / telecredito_cts / continental_cts.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NULL
    RETURN;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'plantilla_apertura_cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'plantilla_apertura_cts',
        'Plantilla Apertura',
        'cts',
        540,
        'plantilla_apertura_cts_page',
        '/cts/plantilla-apertura',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Plantilla Apertura',
        ParentCode = 'cts',
        SortOrder = 540,
        Endpoint = 'plantilla_apertura_cts_page',
        RoutePrefix = '/cts/plantilla-apertura',
        Status = 'A'
    WHERE MenuCode = 'plantilla_apertura_cts';
END

IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
   AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
BEGIN
    INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
    SELECT p.ProfileCode, 'plantilla_apertura_cts'
    FROM dbo.WEB_AccessProfile p
    WHERE p.Status = 'A'
      AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.WEB_AccessProfileMenu x
            WHERE x.ProfileCode = p.ProfileCode
              AND x.MenuCode = 'plantilla_apertura_cts'
      );

    INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
    SELECT DISTINCT m.ProfileCode, 'plantilla_apertura_cts'
    FROM dbo.WEB_AccessProfileMenu m
    WHERE m.MenuCode IN ('formato_cts', 'telecredito_cts', 'continental_cts')
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.WEB_AccessProfileMenu x
            WHERE x.ProfileCode = m.ProfileCode
              AND x.MenuCode = 'plantilla_apertura_cts'
      );
END
GO
