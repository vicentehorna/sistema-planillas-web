/*
    Menú Tareo NG → Reporte de Tareos (hm_ngservicios).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_ng_reporte')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_ng_reporte',
        'Reporte de Tareos',
        'tareo_ng',
        417,
        'tareo_ng_reporte_page',
        '/tareo-ng/reporte',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte de Tareos',
        ParentCode = 'tareo_ng',
        SortOrder = 417,
        Endpoint = 'tareo_ng_reporte_page',
        RoutePrefix = '/tareo-ng/reporte',
        Status = 'A'
    WHERE MenuCode = 'tareo_ng_reporte';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_ng_reporte'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_ng_reporte'
  );
GO
