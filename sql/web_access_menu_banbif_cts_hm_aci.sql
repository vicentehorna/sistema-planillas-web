/*
    Menú CTS → Archivo BANBIF — solo hm_aci.
    Idempotente. Asigna a ADMIN y a perfiles con telecredito_cts / continental_cts.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('cts', 'CTS', NULL, 505, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'banbif_cts')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'banbif_cts',
        'Archivo BANBIF',
        'cts',
        540,
        'banbif_cts_page',
        '/cts/banbif',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Archivo BANBIF',
        ParentCode = 'cts',
        SortOrder = 540,
        Endpoint = 'banbif_cts_page',
        RoutePrefix = '/cts/banbif',
        Status = 'A'
    WHERE MenuCode = 'banbif_cts';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'banbif_cts'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'banbif_cts'
  );

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT DISTINCT M.ProfileCode, 'banbif_cts'
FROM dbo.WEB_AccessProfileMenu M
WHERE M.MenuCode IN ('telecredito_cts', 'continental_cts')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu X
        WHERE X.ProfileCode = M.ProfileCode
          AND X.MenuCode = 'banbif_cts'
  );
GO
