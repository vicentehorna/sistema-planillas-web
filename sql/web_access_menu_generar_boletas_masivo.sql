/*
    Menú Generar Boletas Masivo — solo hm_alamo.
    Debajo de Generar Boletas (SortOrder 1411).
    Idempotente.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'documentos')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES ('documentos', 'Documentos', NULL, 1400, NULL, NULL, 'A');
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'generar_boletas_masivo')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('generar_boletas_masivo', 'Generar Boletas Masivo', 'documentos', 1411,
             'generar_boletas_masivo_page', '/generar_boletas_masivo', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Generar Boletas Masivo',
            ParentCode = 'documentos',
            SortOrder = 1411,
            Endpoint = 'generar_boletas_masivo_page',
            RoutePrefix = '/generar_boletas_masivo',
            Status = 'A'
        WHERE MenuCode = 'generar_boletas_masivo';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
    BEGIN
        /* Mismos perfiles que ya tienen Generar Boletas */
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'generar_boletas_masivo'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode = 'generar_boletas'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'generar_boletas_masivo'
          );

        IF OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
            SELECT p.ProfileCode, 'generar_boletas_masivo'
            FROM dbo.WEB_AccessProfile p
            WHERE p.Status = 'A'
              AND p.ProfileCode = 'ADMIN'
              AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.WEB_AccessProfileMenu x
                    WHERE x.ProfileCode = p.ProfileCode
                      AND x.MenuCode = 'generar_boletas_masivo'
              );
        END
    END
END
GO
