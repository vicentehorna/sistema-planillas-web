/*
    Alta de menú Configurar Conceptos 5ta + permiso a perfiles ADMIN.
    Idempotente: se puede re-ejecutar en cada BD cliente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'configurar_conceptos_5ta')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'configurar_conceptos_5ta',
        'Configurar Conceptos 5ta',
        'impuesto_renta',
        800,
        'configurar_conceptos_5ta_page',
        '/impuesto_renta/configurar_conceptos_5ta',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Configurar Conceptos 5ta',
        ParentCode = 'impuesto_renta',
        SortOrder = 800,
        Endpoint = 'configurar_conceptos_5ta_page',
        RoutePrefix = '/impuesto_renta/configurar_conceptos_5ta',
        Status = 'A'
    WHERE MenuCode = 'configurar_conceptos_5ta';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'configurar_conceptos_5ta'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'configurar_conceptos_5ta'
  );
GO
