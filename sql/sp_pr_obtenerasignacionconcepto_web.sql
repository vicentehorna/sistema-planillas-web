/*
    Detalle de una asignación de concepto (edición).
    Clave: person, company, concept, payrolltype, prperiodstart, costcenter.
    Usado por: POST /api/asignacion-conceptos/detalle
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerasignacionconcepto_web]
    @par_company         VARCHAR(10),
    @par_person          VARCHAR(20),
    @par_concept         VARCHAR(20),
    @par_payrolltype     VARCHAR(20),
    @par_prperiodstart   VARCHAR(10),
    @par_costcenter      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ec.Person AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS nombre,
        ISNULL(e.EmployeeCode, ec.Person) AS employeecode,
        ec.Company AS company,
        ec.Concept AS concept,
        (
            SELECT TOP 1 c.Description
            FROM PR_Concept c
            WHERE c.Company = ec.Company
              AND c.Concept = ec.Concept
        ) AS conceptname,
        ec.PayRollType AS payrolltype,
        ec.PRPeriodStart AS prperiodstart,
        ec.PRPeriodEnd AS prperiodend,
        ec.ConceptValue AS conceptvalue,
        ec.ConceptCurrency AS conceptcurrency,
        ec.FlagApplyFormula AS flagapplyformula,
        ec.FlagFrecuencyType AS flagfrecuencytype,
        ec.CostCenter AS costcenter,
        ec.CostCenterCode AS costcentercode,
        LTRIM(RTRIM(ISNULL(ec.Comments, ''))) AS comments
    FROM PR_EmployeeConcept ec WITH (NOLOCK)
        INNER JOIN PR_Employee e WITH (NOLOCK)
            ON e.Person = ec.Person
           AND e.Company = ec.Company
        INNER JOIN SY_Person sp WITH (NOLOCK)
            ON sp.Person = e.Person
    WHERE ec.Company = @par_company
      AND ec.Person = @par_person
      AND ec.Concept = @par_concept
      AND ec.PayRollType = @par_payrolltype
      AND ec.PRPeriodStart = @par_prperiodstart
      AND ec.CostCenter = @par_costcenter;
END
GO
