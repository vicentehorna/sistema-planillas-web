/*
    Menú CTS → Archivo Telecrédito (hm_ultra, hm_ngservicios).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'telecredito_cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'telecredito_cts',
        'Archivo Telecrédito',
        'cts',
        520,
        'telecredito_cts_page',
        '/cts/telecredito',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Archivo Telecrédito',
        ParentCode = 'cts',
        SortOrder = 520,
        Endpoint = 'telecredito_cts_page',
        RoutePrefix = '/cts/telecredito',
        Status = 'A'
    WHERE MenuCode = 'telecredito_cts';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'telecredito_cts'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'telecredito_cts'
  );
GO
