/*
    Agrega opción de menú AFPs (Tablas) y la asigna a perfiles admin.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'afps')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('afps', 'AFPs', 'tablas', 215, 'afps_page', '/afps', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'AFPs',
            ParentCode = 'tablas',
            SortOrder = 215,
            Endpoint = 'afps_page',
            RoutePrefix = '/afps',
            Status = 'A'
        WHERE MenuCode = 'afps';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'afps'
        FROM dbo.WEB_AccessProfile p
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'afps'
          );
    END
END
GO
