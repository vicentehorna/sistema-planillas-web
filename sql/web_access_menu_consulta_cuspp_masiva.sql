/*
    Menú AFP → Consulta CUSPP Masiva (SOLO hm_lumat).
    Idempotente. Después de Control de Pagos AFP (SortOrder 630).
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NULL
    RETURN;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'afp')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('afp', 'AFP', NULL, 600, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'consulta_cuspp_masiva')
BEGIN
    INSERT INTO dbo.WEB_MenuOption
        (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES
        ('consulta_cuspp_masiva', 'Consulta CUSPP Masiva', 'afp', 630, 'consulta_cuspp_masiva_page', '/afp/consulta-cuspp', 'A');
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Consulta CUSPP Masiva',
        ParentCode = 'afp',
        SortOrder = 630,
        Endpoint = 'consulta_cuspp_masiva_page',
        RoutePrefix = '/afp/consulta-cuspp',
        Status = 'A'
    WHERE MenuCode = 'consulta_cuspp_masiva';
END;

IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
   AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
BEGIN
    INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
    SELECT p.ProfileCode, 'consulta_cuspp_masiva'
    FROM dbo.WEB_AccessProfile p
    WHERE p.Status = 'A'
      AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.WEB_AccessProfileMenu x
            WHERE x.ProfileCode = p.ProfileCode
              AND x.MenuCode = 'consulta_cuspp_masiva'
      );

    INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
    SELECT DISTINCT m.ProfileCode, 'consulta_cuspp_masiva'
    FROM dbo.WEB_AccessProfileMenu m
    WHERE m.MenuCode IN ('afpnet', 'control_pagos_afp')
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.WEB_AccessProfileMenu x
            WHERE x.ProfileCode = m.ProfileCode
              AND x.MenuCode = 'consulta_cuspp_masiva'
      );
END
GO
