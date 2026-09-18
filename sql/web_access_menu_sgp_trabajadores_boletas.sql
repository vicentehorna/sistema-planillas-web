/*
    Menú mínimo hm_sgp: Trabajadores + Generar Boletas
    (padres + opciones + permiso a perfiles ADMIN).
    Idempotente.
*/
SET NOCOUNT ON;

/* Padres */
IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'administracion')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('administracion', 'Administracion', NULL, 300, NULL, NULL, 'A');
END

IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'documentos')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('documentos', 'Documentos', NULL, 1400, NULL, NULL, 'A');
END

/* Trabajadores */
IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'trabajadores')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('trabajadores', 'Trabajadores', 'administracion', 310, 'trabajadores_page', '/trabajadores', 'A');
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Trabajadores',
        ParentCode = 'administracion',
        SortOrder = 310,
        Endpoint = 'trabajadores_page',
        RoutePrefix = '/trabajadores',
        Status = 'A'
    WHERE MenuCode = 'trabajadores';
END

/* Generar Boletas */
IF NOT EXISTS (SELECT 1 FROM dbo.WEB_MenuOption WHERE MenuCode = 'generar_boletas')
BEGIN
    INSERT INTO dbo.WEB_MenuOption (MenuCode, Title, ParentCode, SortOrder, Endpoint, RoutePrefix, Status)
    VALUES ('generar_boletas', 'Generar Boletas', 'documentos', 1410, 'generar_boletas_page', '/generar_boletas', 'A');
END
ELSE
BEGIN
    UPDATE dbo.WEB_MenuOption
    SET Title = 'Generar Boletas',
        ParentCode = 'documentos',
        SortOrder = 1410,
        Endpoint = 'generar_boletas_page',
        RoutePrefix = '/generar_boletas',
        Status = 'A'
    WHERE MenuCode = 'generar_boletas';
END

/* Perfil ADMIN si no existe */
IF NOT EXISTS (SELECT 1 FROM dbo.WEB_AccessProfile WHERE ProfileCode = 'ADMIN')
BEGIN
    INSERT INTO dbo.WEB_AccessProfile (ProfileCode, Name, FlagAdmin, Status, XLastUser, XLastDate)
    VALUES ('ADMIN', 'Administrador', 'Y', 'A', 'SYSTEM', GETDATE());
END

/* Perfil solo Trabajadores + Boletas (para asignar a usuarios SGP) */
IF NOT EXISTS (SELECT 1 FROM dbo.WEB_AccessProfile WHERE ProfileCode = 'SGP_BASICO')
BEGIN
    INSERT INTO dbo.WEB_AccessProfile (ProfileCode, Name, FlagAdmin, Status, XLastUser, XLastDate)
    VALUES ('SGP_BASICO', 'SGP Trabajadores y Boletas', 'N', 'A', 'SYSTEM', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.WEB_AccessProfile
    SET Name = 'SGP Trabajadores y Boletas', FlagAdmin = 'N', Status = 'A'
    WHERE ProfileCode = 'SGP_BASICO';
END

/* Permisos ADMIN a menús mínimos */
INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT P.ProfileCode, v.MenuCode
FROM dbo.WEB_AccessProfile P
CROSS JOIN (VALUES ('trabajadores'), ('generar_boletas'), ('administracion'), ('documentos')) v(MenuCode)
WHERE P.Status = 'A'
  AND (P.FlagAdmin = 'Y' OR P.ProfileCode = 'ADMIN')
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.WEB_AccessProfileMenu M
        WHERE M.ProfileCode = P.ProfileCode
          AND M.MenuCode = v.MenuCode
  );

/* Permisos SGP_BASICO: solo las 2 opciones (sin padres vacíos si la UI los requiere, incluir padres) */
INSERT INTO dbo.WEB_AccessProfileMenu (ProfileCode, MenuCode)
SELECT 'SGP_BASICO', v.MenuCode
FROM (VALUES ('administracion'), ('documentos'), ('trabajadores'), ('generar_boletas')) v(MenuCode)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.WEB_AccessProfileMenu M
    WHERE M.ProfileCode = 'SGP_BASICO' AND M.MenuCode = v.MenuCode
);

SELECT 'OK menu minimo trabajadores+boletas' AS mensaje;
GO
