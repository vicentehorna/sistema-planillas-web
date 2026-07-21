/*
    Cabecera y detalle de plantilla de importación de conceptos.
    Usado por: POST /api/plantillas-importacion/obtener

    Resultset 1: cabecera
    Resultset 2: detalle (líneas)

    Nota: en datos legacy PR_ImportConceptDetail.Company puede ser NULL;
    se aceptan filas sin compañía o con la compañía de la cabecera.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerimportconcept_web]
    @company       VARCHAR(4),
    @importconcept VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @importconcept = LTRIM(RTRIM(ISNULL(@importconcept, '')));

    SELECT
        ic.ImportConcept AS importconcept,
        ic.Company AS company,
        LTRIM(RTRIM(ISNULL(ic.Name, ''))) AS name,
        ic.XlastUser AS xlastuser,
        ic.XlastDate AS xlastdate
    FROM PR_ImportConcept ic (NOLOCK)
    WHERE ic.Company = @company
      AND ic.ImportConcept = @importconcept;

    SELECT
        d.Line AS line,
        d.Concept AS concept,
        LTRIM(RTRIM(ISNULL(d.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(c.Description, ''))) AS concept_description,
        LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) AS formulacode
    FROM PR_ImportConceptDetail d (NOLOCK)
        LEFT JOIN PR_Concept c (NOLOCK)
            ON c.Concept = d.Concept
           AND c.Company = @company
    WHERE d.ImportConcept = @importconcept
      AND (
            ISNULL(LTRIM(RTRIM(d.Company)), '') = ''
         OR d.Company = @company
      )
    ORDER BY d.Line ASC;
END
GO
