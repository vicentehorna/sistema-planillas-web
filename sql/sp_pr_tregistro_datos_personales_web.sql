/*
    T-REGISTRO Estructura 04 — Datos personales (generación TXT RP_RUC.ide).

    Usado por: POST /api/plame/t-registro/generar-txt (archivo 04)

    @personas — lista separada por comas de códigos SY_Person.Person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_datos_personales_web]
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
        LTRIM(RTRIM(ISNULL(PDT_DOC.Pdt, ''))) AS documenttype,
        LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(CID.Pdt, ''))) AS docissuingcountry,
        P.BirthDate AS birthdate,
        LTRIM(RTRIM(ISNULL(P.LastName1, ''))) AS lastname1,
        LTRIM(RTRIM(ISNULL(P.LastName2, ''))) AS lastname2,
        LTRIM(RTRIM(
            ISNULL(P.Name1, '') +
            CASE WHEN ISNULL(P.Name2, '') = '' THEN '' ELSE ' ' + P.Name2 END
        )) AS employeename,
        LTRIM(RTRIM(ISNULL(CAST(P.Sex AS VARCHAR(10)), ''))) AS sex,
        LTRIM(RTRIM(ISNULL(NAC.Nro, ''))) AS nationality,
        LTRIM(RTRIM(ISNULL(P.CodeLDN, ''))) AS codeldn,
        LTRIM(RTRIM(ISNULL(P.SecTelephone, ''))) AS telephone,
        LTRIM(RTRIM(ISNULL(P.Email, ''))) AS email,
        LTRIM(RTRIM(ISNULL(ST1.Pdt, ''))) AS streettype,
        LTRIM(RTRIM(ISNULL(P.StreetName, ''))) AS streetname,
        LTRIM(RTRIM(ISNULL(P.AddressNumber, ''))) AS addressnumber,
        LTRIM(RTRIM(ISNULL(P.Room, ''))) AS room,
        LTRIM(RTRIM(ISNULL(P.Inside, ''))) AS inside,
        LTRIM(RTRIM(ISNULL(P.Apple, ''))) AS apple,
        LTRIM(RTRIM(ISNULL(P.Lot, ''))) AS lot,
        LTRIM(RTRIM(ISNULL(P.Kilometer, ''))) AS kilometer,
        LTRIM(RTRIM(ISNULL(P.Block, ''))) AS block,
        LTRIM(RTRIM(ISNULL(P.Stage, ''))) AS stage,
        LTRIM(RTRIM(ISNULL(Z1.Pdt, ''))) AS zone,
        LTRIM(RTRIM(ISNULL(P.ZoneName, ''))) AS zonename,
        LTRIM(RTRIM(ISNULL(P.Reference, ''))) AS reference,
        LTRIM(RTRIM(ISNULL(LOC1.Pdt, ''))) AS localite,
        LTRIM(RTRIM(ISNULL(ST2.Pdt, ''))) AS streettype2,
        LTRIM(RTRIM(ISNULL(P.StreetName2, ''))) AS streetname2,
        LTRIM(RTRIM(ISNULL(P.AddressNumber2, ''))) AS addressnumber2,
        LTRIM(RTRIM(ISNULL(P.Room2, ''))) AS room2,
        LTRIM(RTRIM(ISNULL(P.Inside2, ''))) AS inside2,
        LTRIM(RTRIM(ISNULL(P.Apple2, ''))) AS apple2,
        LTRIM(RTRIM(ISNULL(P.Lot2, ''))) AS lot2,
        LTRIM(RTRIM(ISNULL(P.Kilometer2, ''))) AS kilometer2,
        LTRIM(RTRIM(ISNULL(P.Block2, ''))) AS block2,
        LTRIM(RTRIM(ISNULL(P.Stage2, ''))) AS stage2,
        LTRIM(RTRIM(ISNULL(Z2.Pdt, ''))) AS zone2,
        LTRIM(RTRIM(ISNULL(P.ZoneName2, ''))) AS zonename2,
        LTRIM(RTRIM(ISNULL(P.Reference2, ''))) AS reference2,
        LTRIM(RTRIM(ISNULL(LOC2.Pdt, ''))) AS localite2,
        '1' AS indicator,
        LTRIM(RTRIM(ISNULL(P.Person, ''))) AS person
    FROM PR_Employee E (NOLOCK)
        INNER JOIN #Personas SEL ON SEL.person = E.Person
        INNER JOIN SY_Person P (NOLOCK) ON P.Person = E.Person
        LEFT JOIN SY_PersonDocumentType PDT_DOC (NOLOCK)
            ON P.EmployeeDocumentType = PDT_DOC.PersonDocumentType
        LEFT JOIN PR_Nacionalidad NAC (NOLOCK)
            ON P.Nationality = NAC.Nacionalidad
        LEFT JOIN SY_StreetType ST1 (NOLOCK)
            ON P.StreetType = ST1.StreetType
        LEFT JOIN SY_Zone Z1 (NOLOCK)
            ON P.Zone = Z1.Zone
        LEFT JOIN SY_Localite LOC1 (NOLOCK)
            ON P.Localite = LOC1.Localite
        LEFT JOIN SY_StreetType ST2 (NOLOCK)
            ON P.StreetType2 = ST2.StreetType
        LEFT JOIN SY_Zone Z2 (NOLOCK)
            ON P.Zone2 = Z2.Zone
        LEFT JOIN SY_Localite LOC2 (NOLOCK)
            ON P.Localite2 = LOC2.Localite
        LEFT JOIN PR_EmployeeCategory EC (NOLOCK)
            ON E.EmployeeCategory = EC.EmployeeCategory
        LEFT JOIN PR_CountryIssuingDocument CID (NOLOCK)
            ON P.CountryIssuing = CID.CountryIssuing
    WHERE E.Company = @cia
      AND ISNULL(EC.PDT, '') <> '3'
    ORDER BY employeename, documentnumber;
END
GO
