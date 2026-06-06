/*
    Datos bancarios de un trabajador para edición web.
    Clave: person + company (@cia).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_bancario_trabajador_web]
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
        ISNULL(e.collectionform, '') AS collectionform,
        ISNULL(cf.description, '') AS collectionform_desc,
        ISNULL(e.salarybank, '') AS salarybank,
        ISNULL(eb.name, '') AS salarybank_desc,
        ISNULL(e.salaryaccounttype, '') AS salaryaccounttype,
        ISNULL(tat.description, '') AS salaryaccounttype_desc,
        ISNULL(e.salaryaccount, '') AS salaryaccount,
        ISNULL(e.socialassistancenumber, '') AS cci,
        ISNULL(e.ctsbank, '') AS ctsbank,
        ISNULL(cb.name, '') AS ctsbank_desc,
        ISNULL(e.ctsaccount, '') AS ctsaccount,
        ISNULL(e.ctscurrency, 'LO') AS ctscurrency
    FROM pr_employee e
        INNER JOIN sy_person sp
            ON sp.person = e.person
        LEFT JOIN sy_company sc
            ON sc.company = e.company
        LEFT JOIN te_collectionform cf
            ON cf.collectionform = e.collectionform
        LEFT JOIN erp_bank eb
            ON eb.bank = e.salarybank
           AND eb.company = e.company
        LEFT JOIN te_accounttype tat
            ON tat.accounttype = e.salaryaccounttype
        LEFT JOIN erp_bank cb
            ON cb.bank = e.ctsbank
           AND cb.company = e.company
    WHERE e.company = @cia
      AND e.person = @person;
END
GO
