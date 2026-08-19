/*
    Menú Tareo NG → Importar Tareo (hm_ngservicios).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_ng')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_ng',
        'Tareo',
        NULL,
        415,
        NULL,
        NULL,
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Tareo',
        ParentCode = NULL,
        SortOrder = 415,
        Status = 'A'
    WHERE MenuCode = 'tareo_ng';
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_ng_importar')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_ng_importar',
        'Importar Tareo',
        'tareo_ng',
        416,
        'tareo_ng_importar_page',
        '/tareo-ng/importar',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Importar Tareo',
        ParentCode = 'tareo_ng',
        SortOrder = 416,
        Endpoint = 'tareo_ng_importar_page',
        RoutePrefix = '/tareo-ng/importar',
        Status = 'A'
    WHERE MenuCode = 'tareo_ng_importar';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_ng_importar'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_ng_importar'
  );
GO
