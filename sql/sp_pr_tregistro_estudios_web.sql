/*
    T-REGISTRO Estructura 29 — Estudios concluidos (generación TXT RP_RUC.edu).

    Usado por: POST /api/plame/t-registro/generar-txt (archivo 29)

    @personas — lista separada por comas de códigos SY_Person.Person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_estudios_web]
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
        LTRIM(RTRIM(ISNULL(p.Person, ''))) AS person,
        LTRIM(RTRIM(ISNULL(pdt.pdt, ''))) AS documenttype,
        LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(cid.Pdt, ''))) AS docissuingcountry,
        CASE
            WHEN il.pdt = '13' OR il.pdt = '11' THEN il.pdt
            WHEN il.pdt >= '14' AND il.pdt <= '21' THEN '13'
            ELSE ''
        END AS instructionlevel,
        LTRIM(RTRIM(ISNULL(il.pdt, ''))) AS nivelinstruccion,
        LTRIM(RTRIM(ISNULL(CAST(p.IsTrainer AS VARCHAR(10)), ''))) AS istrainer,
        LTRIM(RTRIM(ISNULL(p.CostCenter1, ''))) AS costcenter1,
        LTRIM(RTRIM(ISNULL(p.CostCenter2, ''))) AS costcenter2,
        LTRIM(RTRIM(ISNULL(CAST(p.DriverLicenseAntiquity AS VARCHAR(20)), ''))) AS driverlicenseantiquity
    FROM pr_employee e (NOLOCK)
        INNER JOIN #Personas sel ON sel.person = e.Person
        INNER JOIN sy_person p (NOLOCK) ON p.Person = e.Person
        LEFT JOIN sy_persondocumenttype pdt (NOLOCK)
            ON p.employeedocumenttype = pdt.persondocumenttype
        LEFT JOIN pr_instructionlevel il (NOLOCK)
            ON p.instructionlevel = il.instructionlevel
        LEFT JOIN pr_employeecategory ec (NOLOCK)
            ON e.employeecategory = ec.employeecategory
        LEFT JOIN PR_CountryIssuingDocument cid (NOLOCK)
            ON p.CountryIssuing = cid.CountryIssuing
    WHERE e.Company = @cia
      AND ISNULL(ec.PDT, '') <> '3'
    ORDER BY documentnumber;
END
GO
