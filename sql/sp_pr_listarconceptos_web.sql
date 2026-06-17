/*
    Listado de conceptos de planilla por compañía (maestro Conceptos).
    Usado por: POST /api/conceptos/listado

    Filtros: @company (obligatorio), @descripcion (opcional, parcial).
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
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept EC (NOLOCK)
                WHERE EC.Company = C.Company
                  AND EC.Concept = C.Concept
            ) THEN 'N'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept EPC (NOLOCK)
                WHERE EPC.Company = C.Company
                  AND EPC.Concept = C.Concept
            ) THEN 'N'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept P (NOLOCK)
                    INNER JOIN PR_EmployeeAFP A (NOLOCK)
                        ON A.Company = P.Company
                       AND A.Person = P.Person
                       AND A.PayRollType = P.PayRollType
                       AND LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), P.PRPeriod))), 6)
                         = LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), A.PRPeriod))), 6)
                WHERE P.Company = C.Company
                  AND P.Concept = C.Concept
            ) THEN 'N'
            ELSE 'Y'
        END AS puede_eliminar
    FROM PR_Concept C (NOLOCK)
        LEFT JOIN PR_ConceptType T (NOLOCK)
            ON C.ConceptType = T.ConceptType
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
