/*
    Menú Reportes → Vacaciones / Descansos → Reporte de Subsidios.
    Sembrar solo en hm_ultra.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_subsidios')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'reporte_subsidios',
        'Reporte de Subsidios',
        'vacaciones_descansos',
        1235,
        'reporte_subsidios_page',
        '/reporte-subsidios',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte de Subsidios',
        ParentCode = 'vacaciones_descansos',
        SortOrder = 1235,
        Endpoint = 'reporte_subsidios_page',
        RoutePrefix = '/reporte-subsidios',
        Status = 'A'
    WHERE MenuCode = 'reporte_subsidios';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'reporte_subsidios'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'reporte_subsidios'
  );
GO
