/*
    T-REGISTRO Estructura 05 — Datos del trabajador (generación TXT RP_RUC.tra).

    Usado por: POST /api/plame/t-registro/generar-txt (archivo 05)

    @personas — lista separada por comas de códigos SY_Person.Person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_trabajador_web]
    @cia       VARCHAR(10),
    @personas  VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @personas = LTRIM(RTRIM(ISNULL(@personas, '')));

    IF @cia = '' OR @personas = ''
        RETURN;

    CREATE TABLE #Personas (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    INSERT INTO #Personas (person)
    SELECT DISTINCT LTRIM(RTRIM(Split.a.value('.', 'VARCHAR(20)')))
    FROM (
        SELECT CAST('<x>' + REPLACE(@personas, ',', '</x><x>') + '</x>' AS XML) AS x
    ) t
    CROSS APPLY x.nodes('/x') Split(a)
    WHERE LTRIM(RTRIM(Split.a.value('.', 'VARCHAR(20)'))) <> '';

    SELECT DISTINCT
        LTRIM(RTRIM(
            ISNULL(sy_person.LastName1, '') + ' ' +
            ISNULL(sy_person.LastName2, '') + ' ' +
            ISNULL(sy_person.Name1, '') + ' ' +
            ISNULL(sy_person.Name2, '')
        )) AS name,
        LTRIM(RTRIM(ISNULL(sy_persondocumenttype.pdt, ''))) AS documenttype,
        LTRIM(RTRIM(ISNULL(sy_person.DocumentNumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(pr_employeetype.pdt, ''))) AS employeetype,
        LTRIM(RTRIM(ISNULL(pr_regimenlabour.pdt, ''))) AS regimenlabour,
        LTRIM(RTRIM(ISNULL(pr_instructionlevel.pdt, ''))) AS instructionlevel,
        LTRIM(RTRIM(ISNULL(pr_ocupation.pdt, ''))) AS ocupation,
        LTRIM(RTRIM(ISNULL(CAST(sy_person.Discapacity AS VARCHAR(10)), ''))) AS discapacity,
        LTRIM(RTRIM(ISNULL(pr_pensiontype.pdt, ''))) AS pensiontype,
        pr_employee.PensionInscriptionDate AS pensioninscriptiondate,
        LTRIM(RTRIM(ISNULL(pr_employee.AfpCard, ''))) AS afpcard,
        LTRIM(RTRIM(ISNULL(pr_sctr_a.pdt, ''))) AS sctrhealth,
        LTRIM(RTRIM(ISNULL(pr_sctr_b.pdt, ''))) AS sctrpension,
        LTRIM(RTRIM(ISNULL(hr_contractmodality.pdt, ''))) AS contractmodality,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.FlagAlternativeRegimen AS VARCHAR(10)), '0'))) AS flagalternativeregimen,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.FlagMaxWorkingHours AS VARCHAR(10)), '0'))) AS flagmaxworkinghours,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.FlagNightSchedule AS VARCHAR(10)), '0'))) AS flagnightschedule,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.OtherIncomeRentTax AS VARCHAR(10)), '0'))) AS otherincomerenttax,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.IsUnionized AS VARCHAR(10)), '0'))) AS isunionized,
        LTRIM(RTRIM(ISNULL(pr_periodtype.pdt, ''))) AS periodtype,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.AffiliatedOwnEps AS VARCHAR(10)), '0'))) AS affiliatedowneps,
        LTRIM(RTRIM(ISNULL(pr_healthentity.pdt, ''))) AS ownserviceruc,
        LTRIM(RTRIM(ISNULL(pr_employeestatus.pdt, ''))) AS employeestatus,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.RelievedRentTax AS VARCHAR(10)), '0'))) AS relievedrenttax,
        LTRIM(RTRIM(ISNULL(pr_specialstatus.pdt, ''))) AS specialstatus,
        LTRIM(RTRIM(ISNULL(te_collectionform.pdt, ''))) AS collectionform,
        LTRIM(RTRIM(ISNULL(CAST(pr_employee.PensionMembership AS VARCHAR(10)), ''))) AS pensionmembership,
        LTRIM(RTRIM(ISNULL(pr_taxagreement.pdt, ''))) AS taxagreement,
        LTRIM(RTRIM(ISNULL(pr_professionalcategory.pdt, ''))) AS professionalcategory,
        (SELECT TOP 1 PR_EmployeeConcept.ConceptValue
           FROM PR_EmployeeConcept (nolock), PR_Concept (nolock)
          WHERE PR_EmployeeConcept.Concept = PR_Concept.Concept
            AND PR_EmployeeConcept.Company = pr_employee.company
            AND PR_EmployeeConcept.Person = pr_employee.person
            AND PR_Concept.FormulaCode = 'REM_BASICA'
            AND PR_EmployeeConcept.FlagFrecuencyType = 'P'
            AND PR_EmployeeConcept.PRPeriodEnd IS NULL) AS salarybasic,
        (SELECT TOP 1 (PR_EmployeeConcept.ConceptValue * 30)
           FROM PR_EmployeeConcept (nolock), PR_Concept (nolock)
          WHERE PR_EmployeeConcept.Concept = PR_Concept.Concept
            AND PR_EmployeeConcept.Company = pr_employee.company
            AND PR_EmployeeConcept.Person = pr_employee.person
            AND PR_Concept.FormulaCode = 'JOR_DIARIO'
            AND PR_EmployeeConcept.FlagFrecuencyType = 'P'
            AND PR_EmployeeConcept.PRPeriodEnd IS NULL) AS jornalbasic,
        LTRIM(RTRIM(ISNULL(pr_payrolltype.ShortName, ''))) AS planilla,
        '' AS ruccas,
        LTRIM(RTRIM(ISNULL(PR_CountryIssuingDocument.Pdt, ''))) AS docissuingcountry,
        LTRIM(RTRIM(ISNULL(sy_person.Person, ''))) AS person
    FROM pr_employee (nolock)
        INNER JOIN #Personas SEL ON SEL.person = pr_employee.person
        INNER JOIN sy_person (nolock)
            ON sy_person.person = pr_employee.person
        LEFT JOIN pr_pensiontype (nolock)
            ON pr_employee.pensiontype = pr_pensiontype.pensiontype
        LEFT JOIN pr_sctr pr_sctr_a (nolock)
            ON pr_employee.sctrhealth = pr_sctr_a.sctr
        LEFT JOIN pr_sctr pr_sctr_b (nolock)
            ON pr_employee.sctrpension = pr_sctr_b.sctr
        LEFT JOIN hr_contractmodality (nolock)
            ON pr_employee.contractmodality = hr_contractmodality.contractmodality
        INNER JOIN pr_payrolltype (nolock)
            ON pr_employee.payrolltype = pr_payrolltype.payrolltype
        LEFT JOIN pr_periodtype (nolock)
            ON pr_payrolltype.periodtype = pr_periodtype.periodtype
        LEFT JOIN pr_healthentity (nolock)
            ON pr_employee.ownserviceruc = pr_healthentity.healthentity
        LEFT JOIN pr_employeestatus (nolock)
            ON pr_employee.employeestatus = pr_employeestatus.employeestatus
        LEFT JOIN pr_specialstatus (nolock)
            ON pr_employee.specialstatus = pr_specialstatus.specialstatus
        LEFT JOIN te_collectionform (nolock)
            ON pr_employee.collectionform = te_collectionform.collectionform
        LEFT JOIN sy_persondocumenttype (nolock)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        LEFT JOIN pr_employeetype (nolock)
            ON pr_employee.employeetype = pr_employeetype.employeetype
        LEFT JOIN pr_regimenlabour (nolock)
            ON pr_employee.regimenlabour = pr_regimenlabour.regimenlabour
        LEFT JOIN pr_instructionlevel (nolock)
            ON sy_person.instructionlevel = pr_instructionlevel.instructionlevel
        LEFT JOIN pr_ocupation (nolock)
            ON pr_employee.ocupation = pr_ocupation.ocupation
        LEFT JOIN pr_employeecategory (nolock)
            ON pr_employee.employeecategory = pr_employeecategory.employeecategory
        LEFT JOIN pr_taxagreement (nolock)
            ON pr_employee.taxagreement = pr_taxagreement.taxagreement
        LEFT JOIN pr_professionalcategory (nolock)
            ON pr_employee.professionalcategory = pr_professionalcategory.professionalcategory
        LEFT JOIN PR_CountryIssuingDocument (nolock)
            ON SY_Person.CountryIssuing = PR_CountryIssuingDocument.CountryIssuing
    WHERE pr_employeecategory.PDT = '1'
      AND pr_employee.company = @cia
    ORDER BY name ASC;
END
GO
