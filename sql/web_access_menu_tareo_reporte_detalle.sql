/*
    Menú Tareo → Reporte Detalle Tareo (hm_ultra).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_reporte_detalle')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_reporte_detalle',
        'Reporte Detalle Tareo',
        'tareo',
        435,
        'tareo_reporte_detalle_page',
        '/tareo/reporte-detalle',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte Detalle Tareo',
        ParentCode = 'tareo',
        SortOrder = 435,
        Endpoint = 'tareo_reporte_detalle_page',
        RoutePrefix = '/tareo/reporte-detalle',
        Status = 'A'
    WHERE MenuCode = 'tareo_reporte_detalle';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_reporte_detalle'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_reporte_detalle'
  );
GO
