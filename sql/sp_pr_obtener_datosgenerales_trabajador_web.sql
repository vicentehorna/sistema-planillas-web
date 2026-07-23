/*
    Datos generales de SY_Person para edición web del trabajador.
    Clave: person + company (@cia) vía PR_Employee.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_datosgenerales_trabajador_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = UPPER(LTRIM(RTRIM(ISNULL(@person, ''))));

    SELECT
        e.person,
        e.company,
        e.employeecode,
        LTRIM(RTRIM(ISNULL(sp.name1, ''))) AS name1,
        LTRIM(RTRIM(ISNULL(sp.name2, ''))) AS name2,
        LTRIM(RTRIM(ISNULL(sp.lastname1, ''))) AS lastname1,
        LTRIM(RTRIM(ISNULL(sp.lastname2, ''))) AS lastname2,
        sp.birthdate AS birthdate,
        LTRIM(RTRIM(ISNULL(sp.sex, ''))) AS sex,
        LTRIM(RTRIM(ISNULL(sp.name, ''))) AS name,
        LTRIM(RTRIM(ISNULL(sp.sectelephone, ''))) AS sectelephone,
        LTRIM(RTRIM(ISNULL(sp.email, ''))) AS email,
        LTRIM(RTRIM(ISNULL(sp.address, ''))) AS address,
        LTRIM(RTRIM(ISNULL(sp.nacionalidad, ''))) AS nacionalidad,
        LTRIM(RTRIM(ISNULL(
            COALESCE(
                (
                    SELECT TOP 1 dt0.PersonDocumentType
                    FROM SY_PersonDocumentType dt0 (NOLOCK)
                    WHERE dt0.Company = e.Company
                      AND dt0.PersonDocumentType = sp.EmployeeDocumentType
                ),
                (
                    SELECT TOP 1 dt2.PersonDocumentType
                    FROM SY_PersonDocumentType dt1 (NOLOCK)
                    INNER JOIN SY_PersonDocumentType dt2 (NOLOCK)
                        ON dt2.Company = e.Company
                       AND LTRIM(RTRIM(ISNULL(dt2.PDT, ''))) = LTRIM(RTRIM(ISNULL(dt1.PDT, '')))
                       AND LTRIM(RTRIM(ISNULL(dt1.PDT, ''))) <> ''
                    WHERE dt1.PersonDocumentType = sp.EmployeeDocumentType
                    ORDER BY dt2.PersonDocumentType
                ),
                (
                    SELECT TOP 1 dt2.PersonDocumentType
                    FROM SY_PersonDocumentType dt1 (NOLOCK)
                    INNER JOIN SY_PersonDocumentType dt2 (NOLOCK)
                        ON dt2.Company = e.Company
                       AND UPPER(LTRIM(RTRIM(ISNULL(dt2.Description, '')))) =
                           UPPER(LTRIM(RTRIM(ISNULL(dt1.Description, ''))))
                    WHERE dt1.PersonDocumentType = sp.EmployeeDocumentType
                    ORDER BY dt2.PersonDocumentType
                ),
                sp.EmployeeDocumentType
            ),
            ''
        ))) AS employeedocumenttype,
        LTRIM(RTRIM(ISNULL(dt.description, ''))) AS employeedocumenttype_desc,
        LTRIM(RTRIM(ISNULL(sp.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(sp.replicationunit, ''))) AS replicationunit,
        LTRIM(RTRIM(ISNULL(ru.description, ISNULL(ru.name, '')))) AS replicationunit_desc,
        LTRIM(RTRIM(ISNULL(sp.userid, ''))) AS userid,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        ISNULL(sc.description, '') AS company_desc
    FROM pr_employee e (NOLOCK)
        INNER JOIN sy_person sp (NOLOCK)
            ON sp.person = e.person
        LEFT JOIN sy_company sc (NOLOCK)
            ON sc.company = e.company
        LEFT JOIN sy_persondocumenttype dt (NOLOCK)
            ON dt.persondocumenttype = COALESCE(
                (
                    SELECT TOP 1 dt0.PersonDocumentType
                    FROM SY_PersonDocumentType dt0 (NOLOCK)
                    WHERE dt0.Company = e.Company
                      AND dt0.PersonDocumentType = sp.EmployeeDocumentType
                ),
                (
                    SELECT TOP 1 dt2.PersonDocumentType
                    FROM SY_PersonDocumentType dt1 (NOLOCK)
                    INNER JOIN SY_PersonDocumentType dt2 (NOLOCK)
                        ON dt2.Company = e.Company
                       AND LTRIM(RTRIM(ISNULL(dt2.PDT, ''))) = LTRIM(RTRIM(ISNULL(dt1.PDT, '')))
                       AND LTRIM(RTRIM(ISNULL(dt1.PDT, ''))) <> ''
                    WHERE dt1.PersonDocumentType = sp.EmployeeDocumentType
                    ORDER BY dt2.PersonDocumentType
                ),
                (
                    SELECT TOP 1 dt2.PersonDocumentType
                    FROM SY_PersonDocumentType dt1 (NOLOCK)
                    INNER JOIN SY_PersonDocumentType dt2 (NOLOCK)
                        ON dt2.Company = e.Company
                       AND UPPER(LTRIM(RTRIM(ISNULL(dt2.Description, '')))) =
                           UPPER(LTRIM(RTRIM(ISNULL(dt1.Description, ''))))
                    WHERE dt1.PersonDocumentType = sp.EmployeeDocumentType
                    ORDER BY dt2.PersonDocumentType
                ),
                sp.EmployeeDocumentType
            )
           AND dt.company = e.company
        LEFT JOIN sy_replicationunit ru (NOLOCK)
            ON ru.replicationunit = sp.replicationunit
    WHERE e.company = @cia
      AND e.person = @person;
END
GO
