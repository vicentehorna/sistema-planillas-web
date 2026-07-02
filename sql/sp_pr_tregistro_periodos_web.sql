/*
    T-REGISTRO Estructura 11 — Datos de períodos (generación TXT RP_RUC.per).

    Usado por: POST /api/plame/t-registro/generar-txt (archivo 11)

    @personas — lista separada por comas de códigos SY_Person.Person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_periodos_web]
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
        LTRIM(RTRIM(ISNULL(PR_CountryIssuingDocument.Pdt, ''))) AS countryissuingdocument,
        LTRIM(RTRIM(ISNULL(pr_employeecategory.PDT, ''))) AS employeecategory,
        CASE
            WHEN ISNULL(pr_employee.ReEntryDate, '') = '' THEN pr_employee.EntryDate
            ELSE pr_employee.ReEntryDate
        END AS entrydate,
        pr_employee.CeaseDate AS ceasedate,
        LTRIM(RTRIM(ISNULL(pr_ceasereason.pdt, ''))) AS ceasereason,
        (SELECT TOP 1 PeriodsIndicators.StartDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '2'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS startdate2,
        (SELECT TOP 1 PeriodsIndicators.EndDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '2'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS enddate2,
        (SELECT TOP 1 pr_employeetype.PDT
           FROM PeriodsIndicators (NOLOCK)
                LEFT JOIN pr_employeetype (NOLOCK)
                    ON PeriodsIndicators.Indicator = pr_employeetype.employeetype
          WHERE PeriodsIndicators.RecordType = '2'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS indicator2,
        (SELECT TOP 1 PeriodsIndicators.StartDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '3'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS startdate3,
        (SELECT TOP 1 PeriodsIndicators.EndDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '3'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS enddate3,
        (SELECT TOP 1 PR_REGIMEHEALTH.Pdt
           FROM PeriodsIndicators (NOLOCK)
                LEFT JOIN PR_REGIMEHEALTH (NOLOCK)
                    ON PeriodsIndicators.Indicator = PR_REGIMEHEALTH.RegimeHealth
          WHERE PeriodsIndicators.RecordType = '3'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS indicator3,
        (SELECT TOP 1 PeriodsIndicators.StartDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '4'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS startdate4,
        (SELECT TOP 1 PeriodsIndicators.EndDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '4'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS enddate4,
        CASE
            WHEN (
                SELECT TOP 1 b.Pdt
                  FROM pr_employee a (NOLOCK)
                       INNER JOIN PR_PENSIONTYPE b (NOLOCK)
                           ON a.PensionType = b.PensionType
                          AND a.Company = b.Company
                 WHERE b.Company = @cia
                   AND a.Person = pr_employee.Person
            ) = '02' THEN '02'
            ELSE (
                SELECT TOP 1 b.Pdt
                  FROM pr_employee a (NOLOCK)
                       INNER JOIN PR_PENSIONTYPE b (NOLOCK)
                           ON a.PensionType = b.PensionType
                          AND a.Company = b.Company
                 WHERE b.Company = @cia
                   AND a.Person = pr_employee.Person
            )
        END AS indicator4,
        (SELECT TOP 1 PeriodsIndicators.StartDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '5'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS startdate5,
        (SELECT TOP 1 PeriodsIndicators.EndDate
           FROM PeriodsIndicators (NOLOCK)
          WHERE PeriodsIndicators.RecordType = '5'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS enddate5,
        (SELECT TOP 1 PR_SCTR.PDT
           FROM PeriodsIndicators (NOLOCK), PR_SCTR (NOLOCK)
          WHERE PeriodsIndicators.Indicator = PR_SCTR.SCTR
            AND PR_SCTR.SCTRType = 'H'
            AND PeriodsIndicators.RecordType = '5'
            AND PeriodsIndicators.Status = 'A'
            AND PeriodsIndicators.Company = pr_employee.Company
            AND PeriodsIndicators.Person = pr_employee.Person) AS indicator5,
        LTRIM(RTRIM(ISNULL(PR_REGIMEHEALTH.Pdt, ''))) AS regimehealth,
        LTRIM(RTRIM(ISNULL(pr_healthentity.pdt, ''))) AS healthentity,
        LTRIM(RTRIM(ISNULL(sy_person.Person, ''))) AS person
    FROM pr_employee (NOLOCK)
        INNER JOIN #Personas SEL ON SEL.person = pr_employee.person
        INNER JOIN sy_person (NOLOCK)
            ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        LEFT JOIN pr_healthentity (NOLOCK)
            ON pr_employee.ownserviceruc = pr_healthentity.healthentity
        LEFT JOIN pr_employeecategory (NOLOCK)
            ON pr_employee.employeecategory = pr_employeecategory.employeecategory
        LEFT JOIN PR_CountryIssuingDocument (NOLOCK)
            ON SY_Person.CountryIssuing = PR_CountryIssuingDocument.CountryIssuing
        LEFT JOIN pr_ceasereason (NOLOCK)
            ON PR_Employee.CeaseReason = pr_ceasereason.CeaseReason
        LEFT JOIN PR_REGIMEHEALTH (NOLOCK)
            ON pr_employee.regimehealth = PR_REGIMEHEALTH.RegimeHealth
    WHERE pr_employee.company = @cia
    ORDER BY name ASC;
END
GO
