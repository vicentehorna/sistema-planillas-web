/*
    Menú AFP NET Masivo — inicialmente solo hm_alamo.
    Ejecutar en hm_alamo después del deploy web.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'afpnet_masivo')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('afpnet_masivo', 'AFP NET Masivo', 'afp', 615, 'declaracion_afp_masivo_page', '/afp/declaracion-masivo', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'AFP NET Masivo',
            ParentCode = 'afp',
            SortOrder = 615,
            Endpoint = 'declaracion_afp_masivo_page',
            RoutePrefix = '/afp/declaracion-masivo',
            Status = 'A'
        WHERE MenuCode = 'afpnet_masivo';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'afpnet_masivo'
        FROM dbo.WEB_AccessProfile p
        WHERE p.FlagAdmin = 'Y'
          AND p.Status = 'A'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'afpnet_masivo'
          );
    END
END
GO
