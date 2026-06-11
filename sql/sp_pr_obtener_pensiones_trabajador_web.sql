/*
    Datos de pensiones de un trabajador para edición web.
    Clave: person + company (@cia).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_pensiones_trabajador_web]
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
        ISNULL(sp.documentnumber, '') AS numerodocumento,
        ISNULL(sc.description, '') AS company_desc,
        ISNULL(e.pensiontype, '') AS pensiontype,
        ISNULL(pt.description, '') AS pensiontype_desc,
        CASE
            WHEN e.pensioninscriptiondate IS NULL THEN ''
            ELSE CONVERT(VARCHAR(10), e.pensioninscriptiondate, 23)
        END AS pensioninscriptiondate,
        ISNULL(e.regimehealth, '') AS regimehealth,
        ISNULL(rh.description, '') AS regimehealth_desc,
        CASE WHEN LTRIM(RTRIM(ISNULL(e.flagmixta, 'N'))) = 'Y' THEN 'Y' ELSE 'N' END AS flagmixta,
        CASE WHEN LTRIM(RTRIM(ISNULL(e.flagasigfamiliar, 'N'))) = 'Y' THEN 'Y' ELSE 'N' END AS flagasigfamiliar
    FROM pr_employee e
        INNER JOIN sy_person sp
            ON sp.person = e.person
        LEFT JOIN sy_company sc
            ON sc.company = e.company
        LEFT JOIN pr_pensiontype pt
            ON pt.pensiontype = e.pensiontype
           AND (LTRIM(RTRIM(ISNULL(pt.company, ''))) = '' OR pt.company = e.company)
        LEFT JOIN pr_regimehealth rh
            ON rh.regimehealth = e.regimehealth
           AND (LTRIM(RTRIM(ISNULL(rh.company, ''))) = '' OR rh.company = e.company)
    WHERE e.company = @cia
      AND e.person = @person;
END
GO
