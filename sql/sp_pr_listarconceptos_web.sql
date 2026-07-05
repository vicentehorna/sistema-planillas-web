/*
    Listado de conceptos de planilla por compañía (maestro Conceptos).
    Usado por: POST /api/conceptos/listado

    Filtros: @company (obligatorio), @descripcion (opcional, parcial).

    Optimización: puede_eliminar con LEFT JOIN agregados (evita EXISTS correlacionados
    por fila). La comprobación AFP vía EPC es redundante si ya existe en EPC.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarconceptos_web]
    @company     VARCHAR(4),
    @descripcion VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @descripcion = NULLIF(LTRIM(RTRIM(ISNULL(@descripcion, ''))), '');

    SELECT
        C.Concept AS concept,
        C.Description AS description,
        ISNULL(C.pdt, '') AS pdt,
        ISNULL(T.ShortName, '') AS tiposhortname,
        ISNULL(T.Description, '') AS tipodescription,
        C.FormulaCode AS formulacode,
        ISNULL(C.reporden, 0) AS reporden,
        C.XLastDate AS xlastdate,
        CASE
            WHEN EC.Concept IS NOT NULL OR EPC.Concept IS NOT NULL THEN 'N'
            ELSE 'Y'
        END AS puede_eliminar
    FROM PR_Concept C (NOLOCK)
        LEFT JOIN PR_ConceptType T (NOLOCK)
            ON C.ConceptType = T.ConceptType
           AND T.Company = C.Company
        LEFT JOIN (
            SELECT DISTINCT Company, Concept
            FROM PR_EmployeeConcept (NOLOCK)
            WHERE Company = @company
        ) EC
            ON EC.Company = C.Company
           AND EC.Concept = C.Concept
        LEFT JOIN (
            SELECT DISTINCT Company, Concept
            FROM PR_EmployeePayRollConcept (NOLOCK)
            WHERE Company = @company
        ) EPC
            ON EPC.Company = C.Company
           AND EPC.Concept = C.Concept
    WHERE C.Company = @company
      AND (
            @descripcion IS NULL
         OR C.Description LIKE '%' + @descripcion + '%'
         OR C.FormulaCode LIKE '%' + @descripcion + '%'
         OR C.PrintText LIKE '%' + @descripcion + '%'
      )
    ORDER BY
        C.Description ASC,
        C.FormulaCode ASC;
END
GO
