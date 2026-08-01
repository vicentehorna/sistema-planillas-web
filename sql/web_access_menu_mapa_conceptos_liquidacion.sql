/*
    Alta de menú Mapa conceptos liquidación (vista analista) + permiso ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'mapa_conceptos_liquidacion')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'mapa_conceptos_liquidacion',
        'Mapa conceptos liquidacion',
        'liquidaciones',
        940,
        'mapa_conceptos_liquidacion_page',
        '/liquidaciones/mapa_conceptos_liquidacion',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Mapa conceptos liquidacion',
        ParentCode = 'liquidaciones',
        SortOrder = 940,
        Endpoint = 'mapa_conceptos_liquidacion_page',
        RoutePrefix = '/liquidaciones/mapa_conceptos_liquidacion',
        Status = 'A'
    WHERE MenuCode = 'mapa_conceptos_liquidacion';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'mapa_conceptos_liquidacion'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'mapa_conceptos_liquidacion'
  );
GO
