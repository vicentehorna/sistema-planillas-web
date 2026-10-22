/*
    Alta de menú Saldo Consolidado de Vacaciones (bajo Reportes / Vacaciones y Descansos).
    SOLO hm_alamo. Idempotente.
    Asigna a perfiles ADMIN y a los que ya tienen reporte_saldo_vacaciones.
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.WEB_MenuOption', 'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_saldo_vacaciones_consolidado')
    BEGIN
        INSERT INTO dbo.WEB_MenuOption
            (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
        VALUES
            ('reporte_saldo_vacaciones_consolidado', 'Saldo Consolidado de Vacaciones', 'vacaciones_descansos', 1222,
             'reporte_saldo_vacaciones_consolidado_page', '/reporte-saldo-vacaciones-consolidado', 'A');
    END
    ELSE
    BEGIN
        UPDATE dbo.WEB_MenuOption
        SET Title = 'Saldo Consolidado de Vacaciones',
            ParentCode = 'vacaciones_descansos',
            SortOrder = 1222,
            Endpoint = 'reporte_saldo_vacaciones_consolidado_page',
            RoutePrefix = '/reporte-saldo-vacaciones-consolidado',
            Status = 'A'
        WHERE MenuCode = 'reporte_saldo_vacaciones_consolidado';
    END;

    IF OBJECT_ID('dbo.WEB_AccessProfileMenu', 'U') IS NOT NULL
       AND OBJECT_ID('dbo.WEB_AccessProfile', 'U') IS NOT NULL
    BEGIN
        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT p.ProfileCode, 'reporte_saldo_vacaciones_consolidado'
        FROM dbo.WEB_AccessProfile p
        WHERE p.Status = 'A'
          AND (p.FlagAdmin = 'Y' OR p.ProfileCode = 'ADMIN')
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = p.ProfileCode
                  AND x.MenuCode = 'reporte_saldo_vacaciones_consolidado'
          );

        INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
        SELECT DISTINCT m.ProfileCode, 'reporte_saldo_vacaciones_consolidado'
        FROM dbo.WEB_AccessProfileMenu m
        WHERE m.MenuCode = 'reporte_saldo_vacaciones'
          AND NOT EXISTS (
                SELECT 1
                FROM dbo.WEB_AccessProfileMenu x
                WHERE x.ProfileCode = m.ProfileCode
                  AND x.MenuCode = 'reporte_saldo_vacaciones_consolidado'
          );
    END
END
GO
