/*
    Selector de cuentas contables activas (AC_Account) por compañía.
    Usado por: POST /api/asientos/configurar-conceptos/cuentas
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectoraccount_web]
    @company   VARCHAR(4),
    @busqueda  VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT TOP 200
        LTRIM(RTRIM(a.Account)) AS id,
        LTRIM(RTRIM(ISNULL(a.Code, ''))) AS code,
        LTRIM(RTRIM(ISNULL(a.Name, a.Description))) AS name,
        LTRIM(RTRIM(ISNULL(a.Code, ''))) + ' - ' + LTRIM(RTRIM(ISNULL(a.Name, a.Description))) AS text
    FROM AC_Account a (NOLOCK)
    WHERE a.Company = @company
      AND a.Status = 'A'
      AND (
            @busqueda IS NULL
         OR ISNULL(a.Code, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(a.Name, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(a.Description, '') LIKE '%' + @busqueda + '%'
      )
    ORDER BY a.Code ASC, a.Name ASC;
END
GO
