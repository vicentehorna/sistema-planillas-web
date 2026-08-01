/*
    Alta de menú Planilla Anual por Trabajador + permiso a perfiles ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_planilla_anual_trabajador')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'reporte_planilla_anual_trabajador',
        'Planilla Anual por Trabajador',
        'reportes_planillas',
        1370,
        'reporte_planilla_anual_trabajador_page',
        '/reporte-planilla-anual-trabajador',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Planilla Anual por Trabajador',
        ParentCode = 'reportes_planillas',
        SortOrder = 1370,
        Endpoint = 'reporte_planilla_anual_trabajador_page',
        RoutePrefix = '/reporte-planilla-anual-trabajador',
        Status = 'A'
    WHERE MenuCode = 'reporte_planilla_anual_trabajador';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'reporte_planilla_anual_trabajador'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'reporte_planilla_anual_trabajador'
  );
GO
