/*
    Procesos distintos por descripción para un tipo de planilla (Description).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesos_consolidada_web]
    @payroll_desc VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));

    SELECT DISTINCT
        LTRIM(RTRIM(PT.Description)) AS proceso
    FROM PR_PayRollType PRT (NOLOCK)
        INNER JOIN SY_Company SC (NOLOCK)
            ON SC.Company = PRT.Company
           AND SC.status = 'A'
        INNER JOIN PR_PayRollTypeProcess PTP (NOLOCK)
            ON PTP.Company = PRT.Company
           AND PTP.PayRollType = PRT.PayRollType
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.Company = PTP.Company
           AND PT.ProcessType = PTP.ProcessType
    WHERE LTRIM(RTRIM(PRT.Description)) = @payroll_desc
      AND LTRIM(RTRIM(ISNULL(PT.Description, ''))) <> ''
    ORDER BY 1 ASC;
END
GO
