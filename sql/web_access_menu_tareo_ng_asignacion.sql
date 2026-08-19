/*
    Menú Tareo NG → Asignación de Tareo (hm_ngservicios).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_ng_asignacion')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_ng_asignacion',
        'Asignación de Tareo',
        'tareo_ng',
        418,
        'tareo_ng_asignacion_page',
        '/tareo-ng/asignacion',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Asignación de Tareo',
        ParentCode = 'tareo_ng',
        SortOrder = 418,
        Endpoint = 'tareo_ng_asignacion_page',
        RoutePrefix = '/tareo-ng/asignacion',
        Status = 'A'
    WHERE MenuCode = 'tareo_ng_asignacion';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_ng_asignacion'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_ng_asignacion'
  );
GO
