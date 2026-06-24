/*
    Certificado de quinta — listado de trabajadores con planilla en el año.

    Usado por: POST /get_lista_certificado_quinta

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @anio         — año calendario (ej. 2026)
      @person       — código persona; '0' = todos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadocertificadoquinta_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @anio        VARCHAR(4),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @anio = LTRIM(RTRIM(ISNULL(@anio, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));

    IF @anio = '' OR LEN(@anio) <> 4 OR @anio LIKE '%[^0-9]%'
    BEGIN
        RAISERROR('Año inválido. Use cuatro dígitos (ej. 2026).', 16, 1);
        RETURN;
    END;

    SELECT
        epr.Person AS person,
        p.Name AS nombre,
        MAX(epr.entrydate) AS fechaingreso,
        MAX(epr.ceasedate) AS fechacese,
        p.EMail AS email,
        ISNULL(p.Sex, 0) AS sex
    FROM PR_EmployeePayRoll epr
        INNER JOIN SY_Person p ON epr.Person = p.Person
       
    WHERE epr.Company = @cia
      AND epr.PayRollType = @payrolltype
      AND LEFT(LTRIM(RTRIM(epr.PRPeriod)), 4) = @anio
      AND (@person = '0' OR epr.Person = @person)
      and ISNULL((select COUNT(*) from PR_EmployeePayRollConcept epc inner join PR_Concept c on (epc.Concept = c.Concept) 
        inner join PR_ConceptType ct on (c.ConceptType = ct.ConceptType and ct.ShortName in ('I', 'D')) 
        where  (epr.Company = epc.Company and epr.PRPeriod = epc.PRPeriod and
        epr.PayRollType = epc.PayRollType and epr.ProcessType = epc.ProcessType and epr.Person = epc.Person)
        ),0) > 0
    GROUP BY
        epr.Person,
        p.Name,
        p.EMail,
        p.Sex
    ORDER BY p.Name;
END
GO


