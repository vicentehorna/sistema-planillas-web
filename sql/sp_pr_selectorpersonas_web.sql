/*
    Selector de personas/trabajadores activos por compañía.
    Usado por: GET /api/selectores/trabajadores
               (asignación de conceptos, filtros, etc.)

    @payrolltype opcional: '0'/vacío = todos; código, Description o ShortName de PR_PayRollType.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpersonas_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '0')));
    IF @payrolltype = '' SET @payrolltype = '0';

    SELECT
        e.Person,
        LTRIM(RTRIM(
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(p.Name, ''))), '') IS NOT NULL
                    THEN LTRIM(RTRIM(p.Name))
                ELSE
                    ISNULL(p.LastName1, '') + ' ' +
                    ISNULL(p.LastName2, '') + ' ' +
                    ISNULL(p.Name1, '') + ' ' +
                    ISNULL(p.Name2, '')
            END
        )) AS Name
    FROM PR_Employee e (NOLOCK)
    INNER JOIN SY_Person p (NOLOCK)
        ON p.Person = e.Person
    WHERE e.Company = @cia
      AND e.Status = 'N'
      AND (
            @payrolltype = '0'
         OR e.PayRollType = @payrolltype
         OR e.PayRollType IN (
                SELECT PT.PayRollType
                FROM PR_PayRollType PT (NOLOCK)
                WHERE PT.Company = @cia
                  AND (
                        PT.Description = @payrolltype
                     OR PT.ShortName = @payrolltype
                  )
            )
          )
    ORDER BY Name, e.Person;
END
GO
