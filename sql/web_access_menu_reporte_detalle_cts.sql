/*
    Menú CTS → Detalle de CTS.
    Idempotente. Inicialmente se despliega en hm_ngservicios.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'reporte_detalle_cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'reporte_detalle_cts',
        'Detalle de CTS',
        'cts',
        515,
        'reporte_detalle_cts_page',
        '/cts/reporte_detalle_cts',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Detalle de CTS',
        ParentCode = 'cts',
        SortOrder = 515,
        Endpoint = 'reporte_detalle_cts_page',
        RoutePrefix = '/cts/reporte_detalle_cts',
        Status = 'A'
    WHERE MenuCode = 'reporte_detalle_cts';
END

/* Perfiles activos (admin o no). */
INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'reporte_detalle_cts'
FROM dbo.WEB_AccessProfile P
WHERE ISNULL(P.Status, 'A') IN ('A', '1', 'Y')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'reporte_detalle_cts'
  );

/* También a perfiles que ya tienen formato_cts. */
INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT M.ProfileCode, 'reporte_detalle_cts'
FROM dbo.WEB_AccessProfileMenu M
WHERE M.MenuCode = 'formato_cts'
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu X
        WHERE X.ProfileCode = M.ProfileCode
          AND X.MenuCode = 'reporte_detalle_cts'
  );
GO
