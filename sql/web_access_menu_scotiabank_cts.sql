/*
    Menú CTS → Archivo Scotiabank (todas las BD cliente).
    Idempotente. Asigna a ADMIN y a perfiles con banbif_cts / telecredito_cts / continental_cts / formato_cts.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'scotiabank_cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'scotiabank_cts',
        'Archivo Scotiabank',
        'cts',
        545,
        'scotiabank_cts_page',
        '/cts/scotiabank',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Archivo Scotiabank',
        ParentCode = 'cts',
        SortOrder = 545,
        Endpoint = 'scotiabank_cts_page',
        RoutePrefix = '/cts/scotiabank',
        Status = 'A'
    WHERE MenuCode = 'scotiabank_cts';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'scotiabank_cts'
FROM dbo.WEB_AccessProfile P
WHERE ISNULL(P.Status, 'A') IN ('A', '1', 'Y')
  AND (ISNULL(P.FlagAdmin, 'N') = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'scotiabank_cts'
  );

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT DISTINCT M.ProfileCode, 'scotiabank_cts'
FROM dbo.WEB_AccessProfileMenu M
WHERE M.MenuCode IN ('banbif_cts', 'telecredito_cts', 'continental_cts', 'formato_cts')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu X
        WHERE X.ProfileCode = M.ProfileCode
          AND X.MenuCode = 'scotiabank_cts'
  );
GO
