/*
    T-REGISTRO Estructura 17 — Establecimientos donde labora el trabajador (TXT RP_RUC.est).

    Usado por: POST /api/plame/t-registro/generar-txt (archivo 17)

    @personas     — lista separada por comas de códigos SY_Person.Person
    @fecha_desde  — YYYYMMDD (filtro de período, se usa YYYYMM)
    @fecha_hasta  — YYYYMMDD (filtro de período, se usa YYYYMM)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_establecimiento_web]
    @cia          VARCHAR(10),
    @personas     VARCHAR(MAX),
    @fecha_desde  VARCHAR(20),
    @fecha_hasta  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @personas = LTRIM(RTRIM(ISNULL(@personas, '')));
    SET @fecha_desde = LTRIM(RTRIM(ISNULL(@fecha_desde, '')));
    SET @fecha_hasta = LTRIM(RTRIM(ISNULL(@fecha_hasta, '')));

    IF @cia = '' OR @personas = ''
        RETURN;

    DECLARE @pd CHAR(6);
    DECLARE @ph CHAR(6);

    IF LEN(@fecha_desde) >= 6
        SET @pd = LEFT(@fecha_desde, 6);
    IF LEN(@fecha_hasta) >= 6
        SET @ph = LEFT(@fecha_hasta, 6);
    IF @pd IS NULL OR @ph IS NULL
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
        LTRIM(RTRIM(ISNULL(el.Employee, ''))) AS person,
        LTRIM(RTRIM(ISNULL(pdt.pdt, ''))) AS documenttype,
        LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(cid.Pdt, ''))) AS docissuingcountry,
        LTRIM(RTRIM(COALESCE(
            NULLIF(LTRIM(RTRIM(po.Ruc)), ''),
            NULLIF(LTRIM(RTRIM(cl.RUC)), ''),
            NULLIF(LTRIM(RTRIM(c.RUC)), ''),
            NULLIF(LTRIM(RTRIM(c.Ruc)), '')
        ))) AS ruc,
        LTRIM(RTRIM(COALESCE(
            NULLIF(LTRIM(RTRIM(po.LocalCode)), ''),
            NULLIF(LTRIM(RTRIM(cl.NROLOCALTYPE)), ''),
            '0000'
        ))) AS localcode
    FROM PR_EmployeeLocal el (NOLOCK)
        INNER JOIN #Personas sel ON sel.person = el.Employee
        INNER JOIN PR_Employee e (NOLOCK)
            ON e.Person = el.Employee AND e.Company = el.Company
        INNER JOIN pr_employeecategory ec (NOLOCK)
            ON e.employeecategory = ec.employeecategory
        INNER JOIN SY_Person p (NOLOCK)
            ON p.Person = el.Employee
        LEFT JOIN sy_persondocumenttype pdt (NOLOCK)
            ON p.employeedocumenttype = pdt.persondocumenttype
        LEFT JOIN PR_CountryIssuingDocument cid (NOLOCK)
            ON p.CountryIssuing = cid.CountryIssuing
        LEFT JOIN SY_PersonOffice po (NOLOCK)
            ON po.PersonOffice = el.PersonOffice
        LEFT JOIN PR_COMPANYLOCAL cl (NOLOCK)
            ON cl.COMPANYLOCAL = po.LocalType AND cl.COMPANY = el.Company
        LEFT JOIN SY_Company c (NOLOCK)
            ON c.Company = el.Company
    WHERE el.Company = @cia
      AND ec.PDT = '1'
      AND LEN(LTRIM(RTRIM(ISNULL(el.startperiod, '')))) >= 6
      AND LEFT(el.startperiod, 6) <= @ph
      AND (
            el.endperiod IS NULL
            OR LTRIM(RTRIM(el.endperiod)) = ''
            OR LEN(LTRIM(RTRIM(el.endperiod))) < 6
            OR LEFT(el.endperiod, 6) >= @pd
          )
    ORDER BY documentnumber, localcode, ruc;
END
GO
