/*
    Menú Aperturar Periodos Masivo — hm_alamo y hm_garc.
    Asigna a perfiles admin y a los que ya tienen aperturar_periodos.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'aperturar_periodos_masivo')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('aperturar_periodos_masivo', 'Aperturar Periodos Masivo', 'calculos', 415,
             'aperturar_periodos_masivo_page', '/aperturar-periodos-masivo', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Aperturar Periodos Masivo',
            ParentCode = 'calculos',
            SortOrder = 415,
            Endpoint = 'aperturar_periodos_masivo_page',
            RoutePrefix = '/aperturar-periodos-masivo',
            Status = 'A'
        WHERE MenuCode = 'aperturar_periodos_masivo';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        -- Perfiles admin
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'aperturar_periodos_masivo'
        FROM dbo.WEB_AccessProfile p
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'aperturar_periodos_masivo'
          );

        -- Perfiles que ya tienen aperturar_periodos
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'aperturar_periodos_masivo'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode = 'aperturar_periodos'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'aperturar_periodos_masivo'
          );
    END
END
GO
