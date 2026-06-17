/*
    Detalle de un concepto para edición (maestro Conceptos).
    Usado por: POST /api/conceptos/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerconcepto_web]
    @company VARCHAR(4),
    @concept VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '')));

    SELECT
        C.Concept AS concept,
        C.Company AS company,
        C.Description AS description,
        C.PrintText AS printtext,
        C.FormulaCode AS formulacode,
        C.ConceptType AS concepttype,
        ISNULL(T.Description, '') AS concepttypename,
        C.ConceptCurrency AS conceptcurrency,
        ISNULL(C.FlagIsMonetary, 'N') AS flagismonetary,
        ISNULL(C.Flagassign, 'N') AS flagassign,
        C.ConceptOrder AS conceptorder,
        ISNULL(C.FlagPayrollTicket, 'N') AS flagpayrollticket,
        C.reporden AS reporden,
        ISNULL(C.flagconceptdeclare, 'N') AS flagconceptdeclare,
        ISNULL(C.pdt, '') AS pdt,
        ISNULL(C.FLAGCONTRACT, 'N') AS flagcontract,
        ISNULL(C.Status, 'A') AS status,
        C.flaginsertar AS flaginsertar,
        ISNULL(C.flagafecto5ta, 'N') AS flagafecto5ta,
        ISNULL(C.flagafectoAFP, 'N') AS flagafectoafp,
        C.XLastUser AS xlastuser,
        C.XLastDate AS xlastdate
    FROM PR_Concept C (NOLOCK)
        LEFT JOIN PR_ConceptType T (NOLOCK)
            ON C.ConceptType = T.ConceptType
    WHERE C.Company = @company
      AND C.Concept = @concept;
END
GO
