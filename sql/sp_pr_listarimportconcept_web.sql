/*
    Listado de plantillas de importación de conceptos (PR_ImportConcept).
    Usado por: POST /api/plantillas-importacion/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarimportconcept_web]
    @company  VARCHAR(4),
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        ic.ImportConcept AS importconcept,
        LTRIM(RTRIM(ISNULL(ic.Name, ''))) AS name,
        ic.Company AS company,
        ic.XlastUser AS xlastuser,
        ic.XlastDate AS xlastdate,
        ISNULL((
            SELECT COUNT(*)
            FROM PR_ImportConceptDetail d (NOLOCK)
            WHERE d.ImportConcept = ic.ImportConcept
              AND d.Company = ic.Company
        ), 0) AS lineas
    FROM PR_ImportConcept ic (NOLOCK)
    WHERE ic.Company = @company
      AND (
            @busqueda IS NULL
         OR ic.Name LIKE '%' + @busqueda + '%'
         OR ic.ImportConcept LIKE '%' + @busqueda + '%'
      )
    ORDER BY ic.Name ASC, ic.ImportConcept ASC;
END
GO
