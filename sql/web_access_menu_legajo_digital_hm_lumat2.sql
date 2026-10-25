/*
    Menú Recursos Humanos — Legajo Digital — solo hm_lumat2 (demo PromPerú).
    Idempotente: crea/actualiza la opción y la asigna a perfiles FlagAdmin='Y'.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'legajo_digital')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('legajo_digital', 'Legajo Digital', 'rrhh', 610, 'legajo_digital_page', '/rrhh/legajo-digital', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Legajo Digital',
            ParentCode = 'rrhh',
            SortOrder = 610,
            Endpoint = 'legajo_digital_page',
            RoutePrefix = '/rrhh/legajo-digital',
            Status = 'A'
        WHERE MenuCode = 'legajo_digital';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'legajo_digital'
        FROM dbo.WEB_AccessProfile p
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'legajo_digital'
          );
    END
END
GO
