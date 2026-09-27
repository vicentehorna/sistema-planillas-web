/*
    Listado del maestro de empresas (SY_Company).
    Usado por: POST /api/empresas/listado

    @busqueda — opcional: código, razón social o RUC (parcial).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarempresas_web]
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        LTRIM(RTRIM(C.Company)) AS company,
        LTRIM(RTRIM(ISNULL(C.Description, ''))) AS description,
        UPPER(LTRIM(RTRIM(ISNULL(C.Status, 'A')))) AS status,
        CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(C.Status, 'A')))) = 'A' THEN 'Activo' ELSE 'Inactivo' END AS estado,
        LTRIM(RTRIM(ISNULL(C.RUC, ''))) AS ruc,
        C.XLastDate AS xlastdate
    FROM SY_Company C (NOLOCK)
    WHERE @busqueda IS NULL
       OR C.Company LIKE '%' + @busqueda + '%'
       OR C.Description LIKE '%' + @busqueda + '%'
       OR C.RUC LIKE '%' + @busqueda + '%'
    ORDER BY C.Description ASC, C.Company ASC;
END
GO
