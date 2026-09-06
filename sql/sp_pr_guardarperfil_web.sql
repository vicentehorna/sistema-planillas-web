/*
    Alta de perfil SY_Profile (maestro Usuarios).

    Campos de entrada: @profile, @description
    Valores fijos al grabar:
      Status = 'A'
      ReplicationUnit = 'LIMA'
      XLastUser / XLastDate = auditoría
      Company = @company (opcional)
      flag_admin = 'N' (si la columna existe)

    Usado por: POST /api/usuarios/perfiles/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarperfil_web]
    @profile     VARCHAR(20),
    @description VARCHAR(50) = NULL,
    @xlastuser   VARCHAR(20) = NULL,
    @company     VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @profile = UPPER(LTRIM(RTRIM(ISNULL(@profile, ''))));
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @company = NULLIF(LTRIM(RTRIM(ISNULL(@company, ''))), '');

    IF @profile = ''
    BEGIN
        RAISERROR('Indique el código de perfil.', 16, 1);
        RETURN;
    END;

    IF LEN(@profile) > 20
    BEGIN
        RAISERROR('El código de perfil no puede superar 20 caracteres.', 16, 1);
        RETURN;
    END;

    IF @description = ''
        SET @description = @profile;

    IF LEN(@description) > 50
    BEGIN
        RAISERROR('La descripción no puede superar 50 caracteres.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM SY_Profile (NOLOCK) WHERE Profile = @profile)
    BEGIN
        RAISERROR('Ya existe un perfil con ese código.', 16, 1);
        RETURN;
    END;

    IF COL_LENGTH('dbo.SY_Profile', 'flag_admin') IS NOT NULL
    BEGIN
        INSERT INTO SY_Profile (
            Profile,
            Description,
            Status,
            Company,
            XLastUser,
            ReplicationUnit,
            XLastDate,
            flag_admin
        )
        VALUES (
            @profile,
            @description,
            'A',
            @company,
            @xlastuser,
            'LIMA',
            GETDATE(),
            'N'
        );
    END
    ELSE
    BEGIN
        INSERT INTO SY_Profile (
            Profile,
            Description,
            Status,
            Company,
            XLastUser,
            ReplicationUnit,
            XLastDate
        )
        VALUES (
            @profile,
            @description,
            'A',
            @company,
            @xlastuser,
            'LIMA',
            GETDATE()
        );
    END;

    SELECT
        @profile AS id,
        @description AS text,
        @profile AS profile,
        @description AS description,
        'Perfil registrado correctamente.' AS mensaje;
END
GO
