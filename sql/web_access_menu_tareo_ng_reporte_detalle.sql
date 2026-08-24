/*
    Menú Tareo NG → Reporte Detallado de Tareos (hm_ngservicios).
    Idempotente.
*/
SET NOCOUNT ON;

/* Aclarar título del consolidado existente */
IF EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_ng_reporte')
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte Consolidado',
        Status = 'A'
    WHERE MenuCode = 'tareo_ng_reporte';
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_ng_reporte_detalle')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_ng_reporte_detalle',
        'Reporte Detallado',
        'tareo_ng',
        418,
        'tareo_ng_reporte_detalle_page',
        '/tareo-ng/reporte-detalle',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte Detallado',
        ParentCode = 'tareo_ng',
        SortOrder = 418,
        Endpoint = 'tareo_ng_reporte_detalle_page',
        RoutePrefix = '/tareo-ng/reporte-detalle',
        Status = 'A'
    WHERE MenuCode = 'tareo_ng_reporte_detalle';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_ng_reporte_detalle'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_ng_reporte_detalle'
  );

/* Heredar el mismo acceso que el consolidado para perfiles no admin ya habilitados */
INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT M.ProfileCode, 'tareo_ng_reporte_detalle'
FROM dbo.WEB_AccessProfileMenu M
WHERE M.MenuCode = 'tareo_ng_reporte'
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu X
        WHERE X.ProfileCode = M.ProfileCode
          AND X.MenuCode = 'tareo_ng_reporte_detalle'
  );
GO
