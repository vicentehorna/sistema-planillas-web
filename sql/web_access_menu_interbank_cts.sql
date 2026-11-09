/*
    Menú CTS → Archivo Interbank (todas las BD cliente).
    Idempotente. Asigna a ADMIN y a perfiles con telecredito_cts / continental_cts / banbif_cts / formato_cts.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'interbank_cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'interbank_cts',
        'Archivo Interbank',
        'cts',
        535,
        'interbank_cts_page',
        '/cts/interbank',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Archivo Interbank',
        ParentCode = 'cts',
        SortOrder = 535,
        Endpoint = 'interbank_cts_page',
        RoutePrefix = '/cts/interbank',
        Status = 'A'
    WHERE MenuCode = 'interbank_cts';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'interbank_cts'
FROM dbo.WEB_AccessProfile P
WHERE ISNULL(P.Status, 'A') IN ('A', '1', 'Y')
  AND (ISNULL(P.FlagAdmin, 'N') = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'interbank_cts'
  );

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT DISTINCT M.ProfileCode, 'interbank_cts'
FROM dbo.WEB_AccessProfileMenu M
WHERE M.MenuCode IN ('telecredito_cts', 'continental_cts', 'banbif_cts', 'scotiabank_cts', 'formato_cts')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu X
        WHERE X.ProfileCode = M.ProfileCode
          AND X.MenuCode = 'interbank_cts'
  );
GO
