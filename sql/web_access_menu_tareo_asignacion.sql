/*
    Menú Tareo → Asignación de Tareo (hm_ultra).
    Unifica Asignación de Tareos + Asignación al PLAME.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_asignacion')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_asignacion',
        'Asignación de Tareo',
        'tareo',
        440,
        'tareo_asignacion_page',
        '/tareo/asignacion',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Asignación de Tareo',
        ParentCode = 'tareo',
        SortOrder = 440,
        Endpoint = 'tareo_asignacion_page',
        RoutePrefix = '/tareo/asignacion',
        Status = 'A'
    WHERE MenuCode = 'tareo_asignacion';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_asignacion'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_asignacion'
  );
GO
