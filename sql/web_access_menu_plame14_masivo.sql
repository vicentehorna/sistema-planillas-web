/*
    Menú PLAME Archivo 14 Masivo — inicialmente solo hm_alamo.
    Ejecutar en hm_alamo después del deploy web.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'plame_archivo_14_masivo')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('plame_archivo_14_masivo', 'Archivo 14 Masivo (.jor)', 'plame', 412, 'plame_archivo14_masivo_page', '/plame/archivo-14-masivo', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Archivo 14 Masivo (.jor)',
            ParentCode = 'plame',
            SortOrder = 412,
            Endpoint = 'plame_archivo14_masivo_page',
            RoutePrefix = '/plame/archivo-14-masivo',
            Status = 'A'
        WHERE MenuCode = 'plame_archivo_14_masivo';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'plame_archivo_14_masivo'
        FROM dbo.WEB_AccessProfile p
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'plame_archivo_14_masivo'
          );
    END
END
GO
