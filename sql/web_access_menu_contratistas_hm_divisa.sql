/*
    Alta de menú Planilla de Contratistas (bajo Reportes / Planillas). Solo hm_divisa.
    Idempotente. Asigna a perfiles ADMIN y a los que ya tienen reporte_planilla_vertical.
*/
SET NOCOUNT ON;

IF DB_NAME() <> 'hm_divisa'
BEGIN
    RAISERROR('Script exclusivo de hm_divisa.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_contratistas')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('reporte_contratistas', 'Planilla de Contratistas', 'reportes_planillas', 1390,
             'reporte_contratistas_page', '/reporte-contratistas', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Planilla de Contratistas',
            ParentCode = 'reportes_planillas',
            SortOrder = 1390,
            Endpoint = 'reporte_contratistas_page',
            RoutePrefix = '/reporte-contratistas',
            Status = 'A'
        WHERE MenuCode = 'reporte_contratistas';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'reporte_contratistas'
        FROM dbo.WEB_AccessProfile p
        WHERE p.Status = 'A'
          AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'reporte_contratistas'
          );

        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'reporte_contratistas'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode = 'reporte_planilla_vertical'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'reporte_contratistas'
          );
    END
END
GO
