/*
    Periodos de un tipo de planilla (PR_Period).
    Usado por: POST /api/tipos-planilla/periodos/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarperiodos_payrolltype_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        p.PRPeriod AS prperiod,
        p.DateBegin AS datebegin,
        p.DateEnd AS dateend,
        p.CADateBegin AS cadatebegin,
        p.CADateEnd AS cadateend,
        p.PeriodOrder AS periodorder,
        p.GLPeriod AS glperiod,
        p.XLastUser AS xlastuser,
        p.XLastDate AS xlastdate
    FROM PR_Period p (NOLOCK)
    WHERE p.Company = @company
      AND p.PayRollType = @payrolltype
    ORDER BY p.PRPeriod ASC;
END
GO
