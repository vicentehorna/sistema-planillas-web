/*
    Alta de menú Archivo Scotiabank (Pago de Haberes) + permiso ADMIN.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'pago_scotiabank')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'pago_scotiabank',
        'Archivo Scotiabank',
        'pago_haberes',
        750,
        'pago_haberes_scotiabank_page',
        '/pago-haberes/scotiabank',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Archivo Scotiabank',
        ParentCode = 'pago_haberes',
        SortOrder = 750,
        Endpoint = 'pago_haberes_scotiabank_page',
        RoutePrefix = '/pago-haberes/scotiabank',
        Status = 'A'
    WHERE MenuCode = 'pago_scotiabank';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'pago_scotiabank'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'pago_scotiabank'
  );
GO
