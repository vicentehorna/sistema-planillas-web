/*
    Guarda las empresas asignadas a un usuario (SY_UserCompany).
    Reemplaza todas las asignaciones previas del usuario.

    @empresas — códigos de compañía separados por coma (ej. BGT,SB01,SB02)

    Usado por: POST /api/usuarios-empresa/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarusercompany_web]
    @userid VARCHAR(20),
    @empresas VARCHAR(MAX) = NULL,
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @company VARCHAR(20);
    DECLARE @replicationunit VARCHAR(4);
    DECLARE @empresa VARCHAR(20);
    DECLARE @pos INT;
    DECLARE @resto VARCHAR(MAX);

    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));
    SET @empresas = LTRIM(RTRIM(ISNULL(@empresas, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @userid = ''
    BEGIN
        RAISERROR('Indique el usuario.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM SY_User u (NOLOCK) WHERE u.UserID = @userid)
    BEGIN
        RAISERROR('El usuario no existe.', 16, 1);
        RETURN;
    END

    SELECT
        @company = LTRIM(RTRIM(ISNULL(u.Company, 'BGT'))),
        @replicationunit = LTRIM(RTRIM(ISNULL(u.ReplicationUnit, 'LIMA')))
    FROM SY_User u (NOLOCK)
    WHERE u.UserID = @userid;

    IF @company = ''
        SET @company = 'BGT';
    IF @replicationunit = ''
        SET @replicationunit = 'LIMA';

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM SY_UserCompany
        WHERE UserID = @userid;

        IF @empresas <> ''
        BEGIN
            SET @resto = @empresas + ',';

            WHILE LEN(@resto) > 0
            BEGIN
                SET @pos = CHARINDEX(',', @resto);
                IF @pos = 0
                    BREAK;

                SET @empresa = LTRIM(RTRIM(LEFT(@resto, @pos - 1)));
                SET @resto = SUBSTRING(@resto, @pos + 1, LEN(@resto));

                IF @empresa = ''
                    CONTINUE;

                IF NOT EXISTS (
                    SELECT 1
                    FROM SY_Company c (NOLOCK)
                    WHERE c.Company = @empresa
                      AND UPPER(LTRIM(RTRIM(ISNULL(c.[status], '')))) = 'A'
                )
                BEGIN
                    RAISERROR('La compañía %s no existe o no está activa.', 16, 1, @empresa);
                    ROLLBACK TRAN;
                    RETURN;
                END

                IF NOT EXISTS (
                    SELECT 1
                    FROM SY_UserCompany uc (NOLOCK)
                    WHERE uc.UserID = @userid
                      AND uc.idcompany = @empresa
                )
                BEGIN
                    INSERT INTO SY_UserCompany (
                        company,
                        UserID,
                        XLastUser,
                        ReplicationUnit,
                        XLastDate,
                        idcompany
                    )
                    VALUES (
                        @company,
                        @userid,
                        @xlastuser,
                        @replicationunit,
                        GETDATE(),
                        @empresa
                    );
                END
            END
        END

        COMMIT TRAN;

        SELECT
            @userid AS userid,
            ISNULL((
                SELECT COUNT(*)
                FROM SY_UserCompany uc (NOLOCK)
                WHERE uc.UserID = @userid
            ), 0) AS empresas_asignadas;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
