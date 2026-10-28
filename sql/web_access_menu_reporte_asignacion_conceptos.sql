/*
    Alta de menú Asignación de Conceptos (Reportes / Planillas).
    SOLO hm_alamo (el front también lo restringe). Idempotente.
    Asigna a perfiles ADMIN y a los que ya tienen reporte_planilla_consolidada.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_asignacion_conceptos')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('reporte_asignacion_conceptos', 'Asignación de Conceptos', 'reportes_planillas', 1335,
             'reporte_asignacion_conceptos_page', '/reporte-asignacion-conceptos', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Asignación de Conceptos',
            ParentCode = 'reportes_planillas',
            SortOrder = 1335,
            Endpoint = 'reporte_asignacion_conceptos_page',
            RoutePrefix = '/reporte-asignacion-conceptos',
            Status = 'A'
        WHERE MenuCode = 'reporte_asignacion_conceptos';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'reporte_asignacion_conceptos'
        FROM dbo.WEB_AccessProfile p
        WHERE p.Status = 'A'
          AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'reporte_asignacion_conceptos'
          );

        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'reporte_asignacion_conceptos'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode = 'reporte_planilla_consolidada'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'reporte_asignacion_conceptos'
          );
    END
END
GO
