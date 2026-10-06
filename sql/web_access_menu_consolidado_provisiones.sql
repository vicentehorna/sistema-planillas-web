/*
    Alta de menú Consolidado de Provisiones (bajo Reportes / Planillas). Solo hm_alamo.
    Idempotente. Asigna a perfiles ADMIN y a los que ya tienen reporte_planilla_consolidada.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_consolidado_provisiones')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('reporte_consolidado_provisiones', 'Consolidado de Provisiones', 'reportes_planillas', 1336,
             'reporte_consolidado_provisiones_page', '/reporte-consolidado-provisiones', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Consolidado de Provisiones',
            ParentCode = 'reportes_planillas',
            SortOrder = 1336,
            Endpoint = 'reporte_consolidado_provisiones_page',
            RoutePrefix = '/reporte-consolidado-provisiones',
            Status = 'A'
        WHERE MenuCode = 'reporte_consolidado_provisiones';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'reporte_consolidado_provisiones'
        FROM dbo.WEB_AccessProfile p
        WHERE p.Status = 'A'
          AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'reporte_consolidado_provisiones'
          );

        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'reporte_consolidado_provisiones'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode = 'reporte_planilla_consolidada'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'reporte_consolidado_provisiones'
          );
    END
END
GO
