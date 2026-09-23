/*
    Procesos distintos por descripción para un tipo de planilla (Description).
    @userid: NULL=sin filtro; ''=ninguna; valor=SY_UserCompany.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesos_consolidada_web]
    @payroll_desc VARCHAR(200),
    @userid       VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    DECLARE @filtra BIT = CASE WHEN @userid IS NULL THEN 0 ELSE 1 END;
    DECLARE @uid VARCHAR(30) = LTRIM(RTRIM(ISNULL(@userid, '')));

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
    ORDER BY 1 ASC;
END
GO
