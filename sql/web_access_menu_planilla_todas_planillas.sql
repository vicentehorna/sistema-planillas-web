/*
    Alta de menú Consolidado de Planillas (bajo Reportes / Planillas).
    Idempotente. Asigna a perfiles ADMIN y a los que ya tienen
    reporte_planilla_vertical o reporte_planilla_consolidada.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_planilla_todas_planillas')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('reporte_planilla_todas_planillas', 'Consolidado de Planillas', 'reportes_planillas', 1335,
             'reporte_planilla_todas_planillas_page', '/reporte-planilla-todas-planillas', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Consolidado de Planillas',
            ParentCode = 'reportes_planillas',
            SortOrder = 1335,
            Endpoint = 'reporte_planilla_todas_planillas_page',
            RoutePrefix = '/reporte-planilla-todas-planillas',
            Status = 'A'
        WHERE MenuCode = 'reporte_planilla_todas_planillas';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'reporte_planilla_todas_planillas'
        FROM dbo.WEB_AccessProfile p
        WHERE p.Status = 'A'
          AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'reporte_planilla_todas_planillas'
          );

        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'reporte_planilla_todas_planillas'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode IN ('reporte_planilla_vertical', 'reporte_planilla_consolidada')
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'reporte_planilla_todas_planillas'
          );
    END
END
GO
