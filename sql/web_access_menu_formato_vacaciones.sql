/*
    Alta de menú Formato de Vacaciones + permiso a perfiles ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_formato_vacaciones')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'reporte_formato_vacaciones',
        'Formato de Vacaciones',
        'vacaciones_descansos',
        1225,
        'reporte_formato_vacaciones_page',
        '/reporte-formato-vacaciones',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Formato de Vacaciones',
        ParentCode = 'vacaciones_descansos',
        SortOrder = 1225,
        Endpoint = 'reporte_formato_vacaciones_page',
        RoutePrefix = '/reporte-formato-vacaciones',
        Status = 'A'
    WHERE MenuCode = 'reporte_formato_vacaciones';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'reporte_formato_vacaciones'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'reporte_formato_vacaciones'
  );
GO
