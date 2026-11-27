/*
    Menú Generales → Configuraciones (PR_Mapping2).
    Inicialmente solo hm_globaltec.
    Permiso: perfiles ADMIN / FlagAdmin.
    Idempotente.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'configuraciones')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'configuraciones',
        'Configuraciones',
        'generales',
        108,
        'configuraciones_page',
        '/configuraciones',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Configuraciones',
        ParentCode = 'generales',
        SortOrder = 108,
        Endpoint = 'configuraciones_page',
        RoutePrefix = '/configuraciones',
        Status = 'A'
    WHERE MenuCode = 'configuraciones';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'configuraciones'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (
        P.FlagAdmin = 'Y'
     OR P.ProfileCode = 'ADMIN'
  )
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'configuraciones'
  );
GO
