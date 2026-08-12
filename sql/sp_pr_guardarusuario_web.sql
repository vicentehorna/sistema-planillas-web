/*
    Alta / edición de SY_User (clave web) y perfiles SY_UserProfile.

    @modo: I = nuevo, U = actualizar
    @perfiles: lista separada por comas (ej. 'BOLETAS,ADMIN'). Vacío = sin perfiles.

    Solo mantiene PasswordWeb y perfiles; graba auditoría XLastUser/XLastDate.
    En alta también inicializa Password (= clave web), Status=A, AvailableLogins=1.

    Usado por: POST /api/usuarios/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarusuario_web]
    @modo        CHAR(1),
    @userid      VARCHAR(20),
    @passwordweb VARCHAR(20) = NULL,
    @perfiles    VARCHAR(500) = NULL,
    @xlastuser   VARCHAR(20) = NULL,
    @company     VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @pos INT;
    DECLARE @item VARCHAR(20);
    DECLARE @lista VARCHAR(500);

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));
    SET @passwordweb = LTRIM(RTRIM(ISNULL(@passwordweb, '')));
    SET @perfiles = LTRIM(RTRIM(ISNULL(@perfiles, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @company = NULLIF(LTRIM(RTRIM(ISNULL(@company, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @userid = ''
    BEGIN
        RAISERROR('Indique el código de usuario.', 16, 1);
        RETURN;
    END;

    IF LEN(@userid) > 20
    BEGIN
        RAISERROR('El usuario no puede superar 20 caracteres.', 16, 1);
        RETURN;
    END;

    IF @passwordweb = ''
    BEGIN
        RAISERROR('Indique la clave web.', 16, 1);
        RETURN;
    END;

    IF LEN(@passwordweb) > 20
    BEGIN
        RAISERROR('La clave web no puede superar 20 caracteres.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (SELECT 1 FROM SY_User (NOLOCK) WHERE UserID = @userid)
        BEGIN
            RAISERROR('Ya existe un usuario con ese código.', 16, 1);
            RETURN;
        END;
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM SY_User (NOLOCK) WHERE UserID = @userid)
        BEGIN
            RAISERROR('El usuario no existe.', 16, 1);
            RETURN;
        END;
    END;

    /* Validar perfiles antes de tocar datos */
    IF @perfiles <> ''
    BEGIN
        SET @lista = @perfiles + ',';
        WHILE CHARINDEX(',', @lista) > 0
        BEGIN
            SET @pos = CHARINDEX(',', @lista);
            SET @item = LTRIM(RTRIM(LEFT(@lista, @pos - 1)));
            SET @lista = SUBSTRING(@lista, @pos + 1, LEN(@lista));
            IF @item <> '' AND NOT EXISTS (SELECT 1 FROM SY_Profile (NOLOCK) WHERE Profile = @item)
            BEGIN
                RAISERROR('Perfil inválido: %s', 16, 1, @item);
                RETURN;
            END;
        END;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @modo = 'I'
        BEGIN
            INSERT INTO SY_User (
                UserID,
                Password,
                AvailableLogins,
                CurrentLogins,
                LastLogin,
                Status,
                Company,
                XLastUser,
                ReplicationUnit,
                XLastDate,
                PasswordWeb
            )
            VALUES (
                @userid,
                @passwordweb,
                1,
                0,
                NULL,
                'A',
                @company,
                @xlastuser,
                @replicationunit,
                GETDATE(),
                @passwordweb
            );
        END
        ELSE
        BEGIN
            UPDATE SY_User
            SET PasswordWeb = @passwordweb,
                XLastUser = @xlastuser,
                XLastDate = GETDATE()
            WHERE UserID = @userid;
        END;

        DELETE FROM SY_UserProfile WHERE UserID = @userid;

        IF @perfiles <> ''
        BEGIN
            SET @lista = @perfiles + ',';
            WHILE CHARINDEX(',', @lista) > 0
            BEGIN
                SET @pos = CHARINDEX(',', @lista);
                SET @item = LTRIM(RTRIM(LEFT(@lista, @pos - 1)));
                SET @lista = SUBSTRING(@lista, @pos + 1, LEN(@lista));

                IF @item <> ''
                   AND NOT EXISTS (
                        SELECT 1 FROM SY_UserProfile (NOLOCK)
                        WHERE UserID = @userid AND Profile = @item
                   )
                BEGIN
                    INSERT INTO SY_UserProfile (
                        Profile, UserID, XLastUser, Company, ReplicationUnit, XLastDate
                    )
                    VALUES (
                        @item, @userid, @xlastuser, @company, @replicationunit, GETDATE()
                    );
                END;
            END;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @errmsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@errmsg, 16, 1);
        RETURN;
    END CATCH;

    SELECT @userid AS userid, 'OK' AS resultado;
END
GO
