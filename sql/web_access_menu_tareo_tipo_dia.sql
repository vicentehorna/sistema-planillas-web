/*
    Menú Tareo → Tipo de Día (solo sembrar en hm_ultra / Ultrasegur).
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'tareo_tipo_dia')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'tareo_tipo_dia',
        'Tipo de Día',
        'tareo',
        450,
        'tareo_tipo_dia_page',
        '/tareo/tipo-dia',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Tipo de Día',
        ParentCode = 'tareo',
        SortOrder = 450,
        Endpoint = 'tareo_tipo_dia_page',
        RoutePrefix = '/tareo/tipo-dia',
        Status = 'A'
    WHERE MenuCode = 'tareo_tipo_dia';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'tareo_tipo_dia'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'tareo_tipo_dia'
  );
GO
