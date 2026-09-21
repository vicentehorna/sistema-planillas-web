/*
    Selector de trabajadores para Asignación de Conceptos.
    Incluye activos e inactivos (Status <> 'N' marcados como "(Inactivo)").

    Usado por: GET /api/asignacion-conceptos/trabajadores
               (solo asignacion_conceptos.html — no altera otros selectores).

    @payrolltype opcional: '0'/vacío = todos; código, Description o ShortName.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpersonas_asignacion_web]
    @cia         VARCHAR(10),
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
        ))
        + CASE WHEN e.Status <> 'N' THEN ' (Inactivo)' ELSE '' END
        AS Name
    FROM PR_Employee e (NOLOCK)
    INNER JOIN SY_Person p (NOLOCK)
        ON p.Person = e.Person
    WHERE e.Company = @cia
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
    ORDER BY
        CASE WHEN e.Status = 'N' THEN 0 ELSE 1 END,
        Name,
        e.Person;
END
GO
