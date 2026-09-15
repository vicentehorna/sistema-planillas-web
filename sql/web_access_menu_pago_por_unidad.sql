/*
    Menú Pago por Unidad (Pago de Haberes) — pensado para hm_alamo.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'pago_por_unidad')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'pago_por_unidad',
        'Pago por Unidad',
        'pago_haberes',
        705,
        'pago_haberes_pago_unidad_page',
        '/pago-haberes/pago-unidad',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Pago por Unidad',
        ParentCode = 'pago_haberes',
        SortOrder = 705,
        Endpoint = 'pago_haberes_pago_unidad_page',
        RoutePrefix = '/pago-haberes/pago-unidad',
        Status = 'A'
    WHERE MenuCode = 'pago_por_unidad';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'pago_por_unidad'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'pago_por_unidad'
  );
GO
