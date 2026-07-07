/*
    Empresas activas con indicador de asignación para un usuario (SY_UserCompany).
    Usado por: POST /api/usuarios-empresa/empresas
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarusercompany_empresas_web]
    @userid VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));

    IF @userid = ''
    BEGIN
        RAISERROR('Indique el usuario.', 16, 1);
        RETURN;
    END

    SELECT
        c.Company AS company,
        LTRIM(RTRIM(ISNULL(c.Description, ''))) AS description,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM SY_UserCompany uc (NOLOCK)
                WHERE uc.UserID = @userid
                  AND uc.idcompany = c.Company
            ) THEN 1
            ELSE 0
        END AS asignado
    FROM SY_Company c (NOLOCK)
    WHERE UPPER(LTRIM(RTRIM(ISNULL(c.[status], '')))) = 'A'
    ORDER BY
        LTRIM(RTRIM(ISNULL(c.Description, ''))) ASC,
        c.Company ASC;
END
GO
