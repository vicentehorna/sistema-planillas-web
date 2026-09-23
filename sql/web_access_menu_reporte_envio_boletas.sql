/*
    Alta de menú Reporte Envío de Boletas + permiso a perfiles ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_envio_boletas')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'reporte_envio_boletas',
        'Reporte Envío de Boletas',
        'reportes_planillas',
        1385,
        'reporte_envio_boletas_page',
        '/reporte-envio-boletas',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte Envío de Boletas',
        ParentCode = 'reportes_planillas',
        SortOrder = 1385,
        Endpoint = 'reporte_envio_boletas_page',
        RoutePrefix = '/reporte-envio-boletas',
        Status = 'A'
    WHERE MenuCode = 'reporte_envio_boletas';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'reporte_envio_boletas'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'reporte_envio_boletas'
  );
GO
