/*
    Personas distintas (código) en compañías activas con empleado activo.
    @userid: NULL=sin filtro; ''=ninguna; valor=SY_UserCompany.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpersonas_consolidada_web]
    @userid VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @filtra BIT = CASE WHEN @userid IS NULL THEN 0 ELSE 1 END;
    DECLARE @uid VARCHAR(30) = LTRIM(RTRIM(ISNULL(@userid, '')));

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
      AND (
            @filtra = 0
         OR (
                @uid <> ''
            AND EXISTS (
                    SELECT 1
                    FROM SY_UserCompany uc (NOLOCK)
                    WHERE LTRIM(RTRIM(uc.UserID)) = @uid
                      AND LTRIM(RTRIM(uc.idcompany)) = LTRIM(RTRIM(SC.Company))
                )
            )
          )
    ORDER BY SY_Person.Name ASC;
END
GO
