/*
    Menú Configurar Plame 14 — inicialmente solo hm_zilicom.
    Ejecutar en hm_zilicom después del deploy web.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'plame_config_14')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('plame_config_14', 'Configurar Plame 14', 'plame', 411, 'plame_config_14_page', '/plame/config-14', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Configurar Plame 14',
            ParentCode = 'plame',
            SortOrder = 411,
            Endpoint = 'plame_config_14_page',
            RoutePrefix = '/plame/config-14',
            Status = 'A'
        WHERE MenuCode = 'plame_config_14';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'plame_config_14'
        FROM dbo.WEB_AccessProfile p
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'plame_config_14'
          );
    END
END
GO
