/*
    Menú PLAME Archivo 15/18/26 Masivo — inicialmente solo hm_alamo.
    Ejecutar en hm_alamo después del deploy web.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    ;WITH menus AS (
        SELECT *
        FROM (VALUES
            ('plame_archivo_15_masivo', 'Archivo 15 Masivo (.snl)', 'plame', 422, 'plame_archivo15_masivo_page', '/plame/archivo-15-masivo'),
            ('plame_archivo_18_masivo', 'Archivo 18 Masivo (.rem)', 'plame', 432, 'plame_archivo18_masivo_page', '/plame/archivo-18-masivo'),
            ('plame_archivo_26_masivo', 'Archivo 26 Masivo (.toc)', 'plame', 442, 'plame_archivo26_masivo_page', '/plame/archivo-26-masivo')
        ) AS v(MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix)
    )
    MERGE dbo.WEB_MenuOption AS t
    USING menus AS s
       ON t.MenuCode = s.MenuCode
    WHEN MATCHED THEN
        UPDATE SET
            Title = s.Title,
            ParentCode = s.ParentCode,
            SortOrder = s.SortOrder,
            Endpoint = s.Endpoint,
            RoutePrefix = s.RoutePrefix,
            Status = 'A'
    WHEN NOT MATCHED THEN
        INSERT (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES (s.MenuCode, s.Title, s.ParentCode, s.SortOrder, s.Endpoint, s.RoutePrefix, 'A');

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        /* Misma audiencia que Archivo 14 Masivo (perfiles que ya lo tienen). */
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT x.ProfileCode, m.MenuCode
        FROM dbo.WEB_AccessProfileMenu x
        CROSS JOIN (VALUES
            ('plame_archivo_15_masivo'),
            ('plame_archivo_18_masivo'),
            ('plame_archivo_26_masivo')
        ) AS m(MenuCode)
        WHERE x.MenuCode = 'plame_archivo_14_masivo'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu y
                WHERE y.ProfileCode = x.ProfileCode
                  AND y.MenuCode = m.MenuCode
          );

        /* Fallback admin si aún no hay 14 masivo asignado. */
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, m.MenuCode
        FROM dbo.WEB_AccessProfile p
        CROSS JOIN (VALUES
            ('plame_archivo_15_masivo'),
            ('plame_archivo_18_masivo'),
            ('plame_archivo_26_masivo')
        ) AS m(MenuCode)
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu y
                WHERE y.ProfileCode = p.ProfileCode
                  AND y.MenuCode = m.MenuCode
          );
    END
END
GO
