/*
    Maestro Cuentas Contables — listado AC_Account por compañía.
    Usado por: POST /api/asientos/cuentas-contables/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ac_listar_cuentas_contables_web]
    @company  VARCHAR(4),
    @busqueda VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        A.Account AS account,
        LTRIM(RTRIM(ISNULL(A.Code, ''))) AS code,
        LTRIM(RTRIM(ISNULL(A.Name, ''))) AS name
    FROM AC_Account A (NOLOCK)
    WHERE A.Company = @company
      AND (
            @busqueda IS NULL
         OR A.Code LIKE '%' + @busqueda + '%'
         OR A.Name LIKE '%' + @busqueda + '%'
      )
    ORDER BY A.Code, A.Name;
END
GO
