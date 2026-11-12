/*
    Menú CTS → Pago por Unidad (SOLO hm_alamo).
    Idempotente. Asigna a ADMIN y a perfiles con telecredito_cts / pago_por_unidad.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NULL
    RETURN;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts_pago_por_unidad')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'cts_pago_por_unidad',
        'Pago por Unidad',
        'cts',
        525,
        'cts_pago_por_unidad_page',
        '/cts/pago-unidad',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Pago por Unidad',
        ParentCode = 'cts',
        SortOrder = 525,
        Endpoint = 'cts_pago_por_unidad_page',
        RoutePrefix = '/cts/pago-unidad',
        Status = 'A'
    WHERE MenuCode = 'cts_pago_por_unidad';
END

IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
   AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
BEGIN
    INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
    SELECT p.ProfileCode, 'cts_pago_por_unidad'
    FROM dbo.WEB_AccessProfile p
    WHERE p.Status = 'A'
      AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.WEB_AccessProfileMenu x
            WHERE x.ProfileCode = p.ProfileCode
              AND x.MenuCode = 'cts_pago_por_unidad'
      );

    INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
    SELECT DISTINCT m.ProfileCode, 'cts_pago_por_unidad'
    FROM dbo.WEB_AccessProfileMenu m
    WHERE m.MenuCode IN ('telecredito_cts', 'pago_por_unidad', 'formato_cts')
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.WEB_AccessProfileMenu x
            WHERE x.ProfileCode = m.ProfileCode
              AND x.MenuCode = 'cts_pago_por_unidad'
      );
END
GO
