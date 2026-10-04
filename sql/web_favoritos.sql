/*
    Favoritos del sidebar por usuario web.

    MenuKey = ruta del enlace del sidebar (path + query), p. ej. /plame/archivo-18.
    La web solo muestra un favorito si el enlace existe en el sidebar del usuario,
    así que los permisos de perfil y los menús propios de cada BD se respetan solos.

    Si los SP no existen en la BD, la web oculta la opción Favoritos.
    Usado por: GET/POST /api/favoritos, PUT /api/favoritos/orden.
*/
IF OBJECT_ID('dbo.WEB_UserFavorite', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WEB_UserFavorite (
        UserID     VARCHAR(50)  NOT NULL,
        MenuKey    VARCHAR(200) NOT NULL,
        Title      VARCHAR(120) NULL,
        SortOrder  INT          NOT NULL CONSTRAINT DF_WEB_UserFavorite_Sort DEFAULT (0),
        XLastDate  DATETIME     NULL,
        CONSTRAINT PK_WEB_UserFavorite PRIMARY KEY (UserID, MenuKey)
    );
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_web_favoritos_listar_web]
    @userid VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));

    SELECT MenuKey, ISNULL(Title, '') AS Title, SortOrder
    FROM WEB_UserFavorite (NOLOCK)
    WHERE UserID = @userid
    ORDER BY SortOrder, Title;
END
GO

/*
    @accion: A = agregar (al final), Q = quitar.
    Devuelve la lista actualizada (mismo formato que sp_web_favoritos_listar_web).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_web_favoritos_guardar_web]
    @userid   VARCHAR(50),
    @accion   CHAR(1),
    @menukey  VARCHAR(200),
    @title    VARCHAR(120) = NULL,
    @maximo   INT = 15
AS
BEGIN
    SET NOCOUNT ON;
    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));
    SET @accion = UPPER(LTRIM(RTRIM(ISNULL(@accion, ''))));
    SET @menukey = LTRIM(RTRIM(ISNULL(@menukey, '')));
    SET @title = NULLIF(LTRIM(RTRIM(ISNULL(@title, ''))), '');

    IF @userid = '' OR @menukey = ''
    BEGIN
        RAISERROR('Usuario u opción no válidos.', 16, 1);
        RETURN;
    END;

    IF @accion = 'A'
    BEGIN
        IF EXISTS (SELECT 1 FROM WEB_UserFavorite WHERE UserID = @userid AND MenuKey = @menukey)
        BEGIN
            UPDATE WEB_UserFavorite
            SET Title = ISNULL(@title, Title), XLastDate = GETDATE()
            WHERE UserID = @userid AND MenuKey = @menukey;
        END
        ELSE
        BEGIN
            IF (SELECT COUNT(*) FROM WEB_UserFavorite WHERE UserID = @userid) >= @maximo
            BEGIN
                DECLARE @msg VARCHAR(200) = 'Solo se permiten ' + CAST(@maximo AS VARCHAR(10)) + ' favoritos. Quite alguno antes de agregar otro.';
                RAISERROR(@msg, 16, 1);
                RETURN;
            END;
            INSERT INTO WEB_UserFavorite (UserID, MenuKey, Title, SortOrder, XLastDate)
            SELECT @userid, @menukey, @title,
                   ISNULL((SELECT MAX(SortOrder) FROM WEB_UserFavorite WHERE UserID = @userid), 0) + 1,
                   GETDATE();
        END;
    END
    ELSE IF @accion = 'Q'
    BEGIN
        DELETE FROM WEB_UserFavorite WHERE UserID = @userid AND MenuKey = @menukey;
    END
    ELSE
    BEGIN
        RAISERROR('Acción no válida.', 16, 1);
        RETURN;
    END;

    EXEC dbo.sp_web_favoritos_listar_web @userid = @userid;
END
GO

/*
    @claves: MenuKey separados por salto de línea (CHAR(10)), en el orden deseado.
    Las claves no enviadas quedan al final conservando su orden relativo.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_web_favoritos_ordenar_web]
    @userid  VARCHAR(50),
    @claves  VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));
    SET @claves = ISNULL(@claves, '');

    DECLARE @orden TABLE (MenuKey VARCHAR(200) PRIMARY KEY, Pos INT NOT NULL);
    DECLARE @pos INT = 1, @ini INT = 1, @fin INT, @clave VARCHAR(200);

    WHILE @ini <= LEN(@claves) + 1
    BEGIN
        SET @fin = CHARINDEX(CHAR(10), @claves, @ini);
        IF @fin = 0 SET @fin = LEN(@claves) + 1;
        SET @clave = LTRIM(RTRIM(REPLACE(SUBSTRING(@claves, @ini, @fin - @ini), CHAR(13), '')));
        IF @clave <> '' AND NOT EXISTS (SELECT 1 FROM @orden WHERE MenuKey = @clave)
        BEGIN
            INSERT INTO @orden (MenuKey, Pos) VALUES (@clave, @pos);
            SET @pos = @pos + 1;
        END;
        SET @ini = @fin + 1;
    END;

    ;WITH F AS (
        SELECT F.UserID, F.MenuKey, F.SortOrder,
               ROW_NUMBER() OVER (ORDER BY CASE WHEN O.Pos IS NULL THEN 1 ELSE 0 END, O.Pos, F.SortOrder, F.MenuKey) AS NuevoOrden
        FROM WEB_UserFavorite F
            LEFT JOIN @orden O ON O.MenuKey = F.MenuKey
        WHERE F.UserID = @userid
    )
    UPDATE F SET SortOrder = NuevoOrden;

    EXEC dbo.sp_web_favoritos_listar_web @userid = @userid;
END
GO
