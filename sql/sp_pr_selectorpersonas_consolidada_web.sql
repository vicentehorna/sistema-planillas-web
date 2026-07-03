/*
    Personas distintas (código) en todas las compañías activas con empleado activo.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpersonas_consolidada_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        SY_Person.Person AS person,
        SY_Person.Name AS name
    FROM SY_Person (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Person = SY_Person.Person
        INNER JOIN SY_Company SC (NOLOCK)
            ON SC.Company = E.Company
           AND SC.status = 'A'
    WHERE E.Status = 'A'
    ORDER BY SY_Person.Name ASC;
END
GO
