/*
    Menú CTS → Archivo Continental (BBVA) — todas las BD cliente.
    Idempotente. Misma audiencia que Archivo Telecrédito CTS.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'continental_cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'continental_cts',
        'Archivo Continental',
        'cts',
        530,
        'continental_cts_page',
        '/cts/continental',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Archivo Continental',
        ParentCode = 'cts',
        SortOrder = 530,
        Endpoint = 'continental_cts_page',
        RoutePrefix = '/cts/continental',
        Status = 'A'
    WHERE MenuCode = 'continental_cts';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'continental_cts'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'continental_cts'
  );

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT DISTINCT M.ProfileCode, 'continental_cts'
FROM dbo.WEB_AccessProfileMenu M
WHERE M.MenuCode = 'telecredito_cts'
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu X
        WHERE X.ProfileCode = M.ProfileCode
          AND X.MenuCode = 'continental_cts'
  );
GO
