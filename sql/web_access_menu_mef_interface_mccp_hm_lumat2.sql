/*
    Menú MEF — Interface MCCP — solo hm_lumat2 (presentación PromPerú).
    Ejecutar en hm_lumat2 después del deploy web.
    Idempotente: crea/actualiza la opción y la asigna a perfiles FlagAdmin='Y'.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'mef_interface_mccp')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('mef_interface_mccp', 'Interface MCCP', 'mef', 590, 'mef_interface_mccp_page', '/mef/interface-mccp', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Interface MCCP',
            ParentCode = 'mef',
            SortOrder = 590,
            Endpoint = 'mef_interface_mccp_page',
            RoutePrefix = '/mef/interface-mccp',
            Status = 'A'
        WHERE MenuCode = 'mef_interface_mccp';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'mef_interface_mccp'
        FROM dbo.WEB_AccessProfile p
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'mef_interface_mccp'
          );
    END
END
GO
