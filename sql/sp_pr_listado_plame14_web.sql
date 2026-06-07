/*
    Listado PLAME Archivo 14 — Jornada laboral y sobretiempo.
    Usado por: POST /api/plame/archivo-14/listado (plame_archivo14.html).

    Basado en sp_pr_listado_plame14 legacy (PowerBuilder).

    Parámetros:
      @cia    — código de compañía
      @period — periodo tributario YYYYMM (6 dígitos)

    Campos exportables (pipe |):
      Tipo doc (2), N° doc (15), Horas ord (3), Min ord (2), Horas extra (3), Min extra (2)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame14_web]
    @cia    VARCHAR(4),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    SELECT
        documenttype,
        documentnumber,
        name,
        workinghours,
        workingminutes,
        extrahours,
        extraminutes,
        selection
    FROM (
        SELECT
            CASE WHEN sy_persondocumenttype.pdt = '03' THEN '04' ELSE sy_persondocumenttype.pdt END AS documenttype,
            sy_person.documentnumber AS documentnumber,
            LTRIM(RTRIM(
                ISNULL(sy_person.lastname1, '') + ' ' +
                ISNULL(sy_person.lastname2, '') + ' ' +
                ISNULL(sy_person.name1, '') + ' ' +
                ISNULL(sy_person.name2, '')
            )) AS name,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'WH'
                    )
            ), 0) AS workinghours,
            0 AS workingminutes,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'HE'
                    )
            ), 0) AS extrahours,
            0 AS extraminutes,
            'N' AS selection
        FROM pr_employee (NOLOCK)
            INNER JOIN SY_Company ON (PR_Employee.Company = SY_Company.Company AND pr_employee.company = @cia)
            INNER JOIN sy_person (NOLOCK) ON (sy_person.person = pr_employee.person)
            LEFT JOIN sy_persondocumenttype (NOLOCK) ON (sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype)
            INNER JOIN pr_employeecategory (NOLOCK) ON (pr_employee.employeecategory = pr_employeecategory.employeecategory)
            INNER JOIN pr_mapping (NOLOCK) ON (PR_Employee.Company = PR_Mapping.Company AND pr_mapping.company = @cia)
            INNER JOIN pr_employeepayroll (NOLOCK) ON (
                pr_employeepayroll.PayRollType = pr_employee.PayRollType
                AND pr_employeepayroll.Person = pr_employee.Person
                AND pr_employeepayroll.company = pr_employee.company
                AND pr_employeepayroll.ProcessType IN (pr_mapping.PlanillaProcess, pr_mapping.PlanillaSemProcess)
            )
        WHERE pr_employeecategory.PDT IN ('1')
          AND SUBSTRING(pr_employeepayroll.PRPeriod, 1, 6) = @period
    ) T
    WHERE workinghours > 0
      AND (workinghours + extrahours) > 0
    ORDER BY name ASC;
END
GO
