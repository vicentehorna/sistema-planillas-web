/*
    Alta de menú Reporte de Trabajadores + permiso a perfiles ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_trabajadores')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'reporte_trabajadores',
        'Reporte de Trabajadores',
        'reportes_planillas',
        1380,
        'reporte_trabajadores_page',
        '/reporte-trabajadores',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte de Trabajadores',
        ParentCode = 'reportes_planillas',
        SortOrder = 1380,
        Endpoint = 'reporte_trabajadores_page',
        RoutePrefix = '/reporte-trabajadores',
        Status = 'A'
    WHERE MenuCode = 'reporte_trabajadores';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'reporte_trabajadores'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'reporte_trabajadores'
  );
GO
