/*
    T-REGISTRO Estructura 30 — Cuentas de abono de remuneraciones (TXT RP_RUC.cta).

    Usado por: POST /api/plame/t-registro/generar-txt (archivo 30)

    @personas — lista separada por comas de códigos SY_Person.Person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_cuentas_web]
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

    SELECT
        LTRIM(RTRIM(ISNULL(p.Person, ''))) AS person,
        LTRIM(RTRIM(ISNULL(pdt.Pdt, ''))) AS documenttype,
        LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(cid.Pdt, ''))) AS docissuingcountry,
        LTRIM(RTRIM(ISNULL(
            (SELECT CASE
                WHEN LEN(LTRIM(RTRIM(ISNULL(b.PDT, '')))) = 2
                    THEN '0' + LTRIM(RTRIM(b.PDT))
                ELSE LTRIM(RTRIM(ISNULL(b.PDT, '')))
             END
             FROM erp_bank b (NOLOCK)
             WHERE b.bank = e.SalaryBank),
            ''
        ))) AS salarybank,
        LTRIM(RTRIM(ISNULL(e.SalaryAccount, ''))) AS salaryaccount,
        LTRIM(RTRIM(ISNULL(ec.PDT, ''))) AS employeecategory
    FROM PR_Employee e (NOLOCK)
        INNER JOIN #Personas sel ON sel.person = e.Person
        INNER JOIN SY_Person p (NOLOCK) ON p.Person = e.Person
        LEFT JOIN SY_PersonDocumentType pdt (NOLOCK)
            ON p.EmployeeDocumentType = pdt.PersonDocumentType
        LEFT JOIN PR_EmployeeCategory ec (NOLOCK)
            ON e.EmployeeCategory = ec.EmployeeCategory
        LEFT JOIN PR_CountryIssuingDocument cid (NOLOCK)
            ON p.CountryIssuing = cid.CountryIssuing
    WHERE e.Company = @cia
      AND ISNULL(ec.PDT, '') <> '3'
    ORDER BY documentnumber;
END
GO
