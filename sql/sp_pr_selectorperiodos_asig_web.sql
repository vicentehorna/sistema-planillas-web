/*
    Selector de periodos para asignación / descansos médicos.
    Usado por: GET /api/selectores/periodos-asig
               registro_descansos_medicos.html

    @payrolltype: código PayRollType, o Description/ShortName de la misma compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_asig_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        p.PayRollType,
        SUBSTRING(p.PRPeriod, 1, 4) + '-'
            + SUBSTRING(p.PRPeriod, 5, 2) + '-'
            + SUBSTRING(p.PRPeriod, 7, 2) AS description,
        p.PRPeriod,
        p.GLPeriod,
        p.Company,
        p.ReplicationUnit,
        p.XLastUser,
        p.XLastDate
    FROM PR_Period p (NOLOCK)
    WHERE p.Company = @cia
      AND (
            p.PayRollType = @payrolltype
         OR p.PayRollType IN (
                SELECT PT.PayRollType
                FROM PR_PayRollType PT (NOLOCK)
                WHERE PT.Company = @cia
                  AND (
                        PT.Description = @payrolltype
                     OR PT.ShortName = @payrolltype
                  )
            )
          )
    ORDER BY p.PRPeriod DESC;
END
GO
