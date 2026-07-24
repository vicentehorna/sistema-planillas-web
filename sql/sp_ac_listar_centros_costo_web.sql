/*
    Maestro Centros de Costo — listado AC_CostCenter por compañía.
    Usado por: POST /api/centros-costo/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ac_listar_centros_costo_web]
    @company  VARCHAR(4),
    @busqueda VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        A.CostCenter AS costcenter,
        LTRIM(RTRIM(ISNULL(A.Abbrev, ''))) AS abbrev,
        LTRIM(RTRIM(ISNULL(A.Description, ''))) AS description
    FROM AC_CostCenter A (NOLOCK)
    WHERE A.Company = @company
      AND (
            @busqueda IS NULL
         OR A.Abbrev LIKE '%' + @busqueda + '%'
         OR A.Description LIKE '%' + @busqueda + '%'
         OR A.Name LIKE '%' + @busqueda + '%'
         OR A.CCCode LIKE '%' + @busqueda + '%'
      )
    ORDER BY A.Abbrev, A.Description;
END
GO
