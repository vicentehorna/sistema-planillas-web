/*
    SC_GRATI: suma de un concepto en un proceso desde el inicio del ciclo de gratificación
    hasta @period_end. El ciclo depende del periodo en proceso (@period):
      - Enero a Junio  -> inicio Enero del mismo año
      - Julio a Diciembre -> inicio Julio del mismo año
    Si @period_end es anterior al periodo de inicio del ciclo, devuelve 0.
*/
CREATE OR ALTER FUNCTION [dbo].[f_getSumaConceptosGrati](
    @cia           VARCHAR(20),
    @person        VARCHAR(20),
    @payrolltype   VARCHAR(20),
    @process       VARCHAR(20),
    @period        VARCHAR(20),
    @period_end    VARCHAR(20),
    @concept       VARCHAR(20)
)
RETURNS NUMERIC(19, 4)
AS
BEGIN
    DECLARE @period_begin       VARCHAR(20);
    DECLARE @inicio_ciclo_grati DATE;
    DECLARE @inicio_yyyymm      CHAR(6);
    DECLARE @mes_periodo        INT;
    DECLARE @order_ini          INT;
    DECLARE @order_fin          INT;

    IF ISNULL(LTRIM(RTRIM(@concept)), '') = ''
        RETURN 0;

    IF @period IS NULL OR @period_end IS NULL
        RETURN 0;

    SET @mes_periodo = CONVERT(INT, SUBSTRING(@period, 5, 2));

    SET @inicio_ciclo_grati = CASE
        WHEN @mes_periodo BETWEEN 1 AND 6 THEN CONVERT(DATE, LEFT(@period, 4) + '0101')
        ELSE CONVERT(DATE, LEFT(@period, 4) + '0701')
    END;

    SET @inicio_yyyymm = LEFT(CONVERT(VARCHAR(8), @inicio_ciclo_grati, 112), 6);

    SELECT @period_begin = MIN(p.PRPeriod)
    FROM PR_Period p (NOLOCK)
    WHERE p.Company = @cia
      AND p.PayRollType = @payrolltype
      AND LEFT(p.PRPeriod, 6) >= @inicio_yyyymm;

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
