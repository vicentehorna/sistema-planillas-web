/*
    Menú Reporte de Préstamos (detallado) bajo grupo Préstamos.
    Idempotente. Asigna a perfiles admin y a los que tienen control_prestamos.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_prestamos')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('reporte_prestamos', 'Reporte de Préstamos', 'prestamos', 1220,
             'reporte_prestamos_page', '/reporte-prestamos', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Reporte de Préstamos',
            ParentCode = 'prestamos',
            SortOrder = 1220,
            Endpoint = 'reporte_prestamos_page',
            RoutePrefix = '/reporte-prestamos',
            Status = 'A'
        WHERE MenuCode = 'reporte_prestamos';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'reporte_prestamos'
        FROM dbo.WEB_AccessProfile p
        WHERE p.Status = 'A'
          AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'reporte_prestamos'
          );

        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'reporte_prestamos'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode = 'control_prestamos'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'reporte_prestamos'
          );
    END
END
GO
