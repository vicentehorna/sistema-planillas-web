/*
    SCIngreso: suma de un concepto en un proceso desde el periodo de ingreso/reingreso
    hasta @period_end. Si @period_end es anterior al periodo de ingreso, devuelve 0.
*/
CREATE OR ALTER FUNCTION [dbo].[f_getSumaConceptosIngreso](
    @cia           VARCHAR(20),
    @person        VARCHAR(20),
    @payrolltype   VARCHAR(20),
    @process       VARCHAR(20),
    @period_end    VARCHAR(20),
    @concept       VARCHAR(20),
    @fechaingreso  DATETIME
)
RETURNS NUMERIC(19, 4)
AS
BEGIN
    DECLARE @period_begin VARCHAR(20);
    DECLARE @hire_yyyymm  CHAR(6);
    DECLARE @order_ini    INT;
    DECLARE @order_fin    INT;

    IF ISNULL(LTRIM(RTRIM(@concept)), '') = ''
        RETURN 0;

    IF @period_end IS NULL OR @fechaingreso IS NULL
        RETURN 0;

    SET @hire_yyyymm = LEFT(CONVERT(VARCHAR(8), CONVERT(DATE, @fechaingreso), 112), 6);

    SELECT @period_begin = MIN(p.PRPeriod)
    FROM PR_Period p (NOLOCK)
    WHERE p.Company = @cia
      AND p.PayRollType = @payrolltype
      AND LEFT(p.PRPeriod, 6) >= @hire_yyyymm;

    IF @period_begin IS NULL
        RETURN 0;

    SELECT @order_ini = PeriodOrder
    FROM PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND PRPeriod = @period_begin;

    SELECT @order_fin = PeriodOrder
    FROM PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND PRPeriod = @period_end;

    IF ISNULL(@order_fin, 0) < ISNULL(@order_ini, 0)
        RETURN 0;

    RETURN dbo.f_getSumaConceptosProceso(
        @cia, @person, @payrolltype, @process,
        @period_begin, @period_end, @concept
    );
END
GO
