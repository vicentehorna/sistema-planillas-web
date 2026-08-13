/*
    Datos laborales de un trabajador para edición web.
    Clave: person + company (@cia).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_datoslaborales_trabajador_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.person,
        e.company,
        e.employeecode,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        ISNULL(sc.description, '') AS company_desc,
        ISNULL(e.employeetype, '') AS employeetype,
        ISNULL(et.description, '') AS employeetype_desc,
        ISNULL(e.employeecategory, '') AS employeecategory,
        ISNULL(ec.description, '') AS employeecategory_desc,
        CASE
            WHEN e.entrydate IS NULL THEN ''
            ELSE CONVERT(VARCHAR(10), e.entrydate, 23)
        END AS entrydate,
        CASE
            WHEN e.reentrydate IS NULL THEN ''
            ELSE CONVERT(VARCHAR(10), e.reentrydate, 23)
        END AS reentrydate,
        CASE
            WHEN e.ceasedate IS NULL THEN ''
            ELSE CONVERT(VARCHAR(10), e.ceasedate, 23)
        END AS ceasedate,
        CASE
            WHEN LTRIM(RTRIM(ISNULL(e.Status, 'N'))) = 'N' THEN 'N'
            ELSE 'Y'
        END AS status,
        ISNULL(e.ceasereason, '') AS ceasereason,
        ISNULL(cr.description, '') AS ceasereason_desc,
        ISNULL(e.contractmodality, '') AS contractmodality,
        ISNULL(cm.description, '') AS contractmodality_desc,
        ISNULL(e.ocupation, '') AS ocupation,
        ISNULL(oc.description, '') AS ocupation_desc,
        ISNULL(e.specialstatus, '') AS specialstatus,
        ISNULL(ss.description, '') AS specialstatus_desc,
        ISNULL(e.position, '') AS position,
        ISNULL(pos.description, ISNULL(pos.name, '')) AS position_desc,
        ISNULL(e.costcenter, '') AS costcenter,
        LTRIM(RTRIM(ISNULL(cc.name, e.costcentername))) AS costcentername,
        ISNULL(e.payrolltype, '') AS payrolltype,
        ISNULL(pt.description, '') AS payrolltype_desc,
        ISNULL(e.accountprofile, '') AS accountprofile,
        ISNULL(ap.description, '') AS accountprofile_desc,
        COALESCE(
            e.rembasica,
            (SELECT TOP 1 ec.ConceptValue
               FROM PR_EmployeeConcept ec (NOLOCK)
                    INNER JOIN PR_Concept c (NOLOCK)
                        ON c.Concept = ec.Concept
                       AND c.Company = ec.Company
              WHERE ec.Company = e.company
                AND ec.Person = e.person
                AND c.FormulaCode = 'REM_BASICA'
                AND ec.FlagFrecuencyType = 'P'
                AND ec.PRPeriodEnd IS NULL),
            e.salary,
            0
        ) AS sueldo,
        CASE WHEN LTRIM(RTRIM(ISNULL(e.flagasigfamiliar, 'N'))) = 'Y' THEN 'Y' ELSE 'N' END AS flagasigfamiliar
    FROM pr_employee e
        INNER JOIN sy_person sp
            ON sp.person = e.person
        LEFT JOIN sy_company sc
            ON sc.company = e.company
        LEFT JOIN pr_employeetype et
            ON et.employeetype = e.employeetype
        LEFT JOIN pr_employeecategory ec
            ON ec.employeecategory = e.employeecategory
        LEFT JOIN hr_contractmodality cm
            ON cm.contractmodality = e.contractmodality
        LEFT JOIN pr_ocupation oc
            ON oc.ocupation = e.ocupation
        LEFT JOIN pr_specialstatus ss
            ON ss.specialstatus = e.specialstatus
        LEFT JOIN pr_position pos
            ON pos.position = e.position
        LEFT JOIN ac_costcenter cc
            ON cc.costcenter = e.costcenter
           AND cc.company = e.company
        LEFT JOIN pr_payrolltype pt
            ON pt.payrolltype = e.payrolltype
        LEFT JOIN pr_accountprofile ap
            ON ap.accountprofile = e.accountprofile
        LEFT JOIN pr_ceasereason cr
            ON cr.ceasereason = e.ceasereason
           AND cr.company = e.company
    WHERE e.company = @cia
      AND e.person = @person;
END
GO
