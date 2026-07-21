/*
    Selector de periodos para asignación / descansos médicos.
    Usado por: GET /api/selectores/periodos-asig
               registro_descansos_medicos.html
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_asig_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PR_PERIOD.PAYROLLTYPE,
        SUBSTRING(PR_PERIOD.PRPERIOD, 1, 4) + '-'
            + SUBSTRING(PR_PERIOD.PRPERIOD, 5, 2) + '-'
            + SUBSTRING(PR_PERIOD.PRPERIOD, 7, 2) AS description,
        PR_PERIOD.PRPERIOD,
        PR_PERIOD.GLPERIOD,
        PR_PERIOD.COMPANY,
        PR_PERIOD.REPLICATIONUNIT,
        PR_PERIOD.XLASTUSER,
        PR_PERIOD.XLASTDATE
    FROM PR_PERIOD
    WHERE PayRollType = @payrolltype
      AND Company = @cia
    ORDER BY PR_PERIOD.PRPERIOD DESC;
END
GO
