/*
    Menú Tablas → Horas Trabajadas (solo hm_garc).
    Idempotente. Asigna a perfiles admin activos.
*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'horas_trabajadas')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES (
        'horas_trabajadas',
        'Horas Trabajadas',
        'tablas',
        258,
        'horas_trabajadas_page',
        '/horas-trabajadas',
        'A'
    );
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Horas Trabajadas',
        ParentCode = 'tablas',
        SortOrder = 258,
        Endpoint = 'horas_trabajadas_page',
        RoutePrefix = '/horas-trabajadas',
        Status = 'A'
    WHERE MenuCode = 'horas_trabajadas';
END

INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, 'horas_trabajadas'
FROM dbo.WEB_AccessProfile P
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = 'horas_trabajadas'
  );
GO
