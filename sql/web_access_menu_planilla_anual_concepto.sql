/*
    Alta de menú Planilla Anual por Concepto + permiso a perfiles ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_planilla_anual_concepto')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'reporte_planilla_anual_concepto',
        'Planilla Anual por Concepto',
        'reportes_planillas',
        1375,
        'reporte_planilla_anual_concepto_page',
        '/reporte-planilla-anual-concepto',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Planilla Anual por Concepto',
        ParentCode = 'reportes_planillas',
        SortOrder = 1375,
        Endpoint = 'reporte_planilla_anual_concepto_page',
        RoutePrefix = '/reporte-planilla-anual-concepto',
        Status = 'A'
    WHERE MenuCode = 'reporte_planilla_anual_concepto';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'reporte_planilla_anual_concepto'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'reporte_planilla_anual_concepto'
  );
GO
