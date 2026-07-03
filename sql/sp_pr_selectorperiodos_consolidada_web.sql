/*
    Periodos distintos para planilla + proceso (por Description) en todas las compañías.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_consolidada_web]
    @payroll_desc VARCHAR(200),
    @proceso_desc  VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    SET @proceso_desc = LTRIM(RTRIM(ISNULL(@proceso_desc, '')));

    SELECT DISTINCT
        PC.PRPeriod AS period,
        SUBSTRING(PC.PRPeriod, 1, 4) + '-'
            + SUBSTRING(PC.PRPeriod, 5, 2) + '-'
            + SUBSTRING(PC.PRPeriod, 7, 2) AS periodo
    FROM PR_ProcessControl PC (NOLOCK)
        INNER JOIN PR_PayRollType PRT (NOLOCK)
            ON PRT.Company = PC.Company
           AND PRT.PayRollType = PC.PayRollType
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.Company = PC.Company
           AND PT.ProcessType = PC.ProcessType
        INNER JOIN SY_Company SC (NOLOCK)
            ON SC.Company = PC.Company
           AND SC.status = 'A'
    WHERE PC.Status IN ('A', 'C', 'G')
      AND LTRIM(RTRIM(PRT.Description)) = @payroll_desc
      AND LTRIM(RTRIM(PT.Description)) = @proceso_desc
    ORDER BY PC.PRPeriod DESC;
END
GO
