/*
    Menú Tareo → Reporte Resumen Tareo (hm_ultra).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_reporte_resumen')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_reporte_resumen',
        'Reporte Resumen Tareo',
        'tareo',
        430,
        'tareo_reporte_resumen_page',
        '/tareo/reporte-resumen',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Reporte Resumen Tareo',
        ParentCode = 'tareo',
        SortOrder = 430,
        Endpoint = 'tareo_reporte_resumen_page',
        RoutePrefix = '/tareo/reporte-resumen',
        Status = 'A'
    WHERE MenuCode = 'tareo_reporte_resumen';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_reporte_resumen'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_reporte_resumen'
  );
GO
