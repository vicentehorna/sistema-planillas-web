/*
    Promedio CTS: promedio de un concepto en un proceso y rango de periodos.
    Igual que Promedio Grati / Promedio Vac, pero el periodo inicial depende
    del ciclo CTS según el periodo en proceso:
      - Mayo a Octubre     -> inicio Mayo del mismo año
      - Noviembre a Abril  -> inicio Noviembre
        (año anterior si el periodo es ene–abr; mismo año si nov–dic)
*/
CREATE OR ALTER FUNCTION [dbo].[f_getPromedioCts](
    @cia           VARCHAR(20),
    @person        VARCHAR(20),
    @payrolltype   VARCHAR(20),
    @process       VARCHAR(20),
    @period        VARCHAR(20),
    @period_end    VARCHAR(20),
    @concept       VARCHAR(20),
    @valor_minimo  NUMERIC(19, 4),
    @divisor       NUMERIC(19, 4) = NULL,
    @fechaingreso  DATETIME = NULL
)
RETURNS NUMERIC(19, 4)
AS
BEGIN
    DECLARE @period_begin  VARCHAR(20);
    DECLARE @mes_periodo   INT;
    DECLARE @inicio_yyyymm CHAR(6);

    IF @period IS NULL OR @period_end IS NULL
        RETURN 0;

    SET @mes_periodo = CONVERT(INT, SUBSTRING(@period, 5, 2));

    SET @inicio_yyyymm = CASE
        WHEN @mes_periodo BETWEEN 5 AND 10 THEN LEFT(@period, 4) + '05'
        WHEN @mes_periodo BETWEEN 11 AND 12 THEN LEFT(@period, 4) + '11'
        ELSE CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '11'
    END;

    SELECT @period_begin = MIN(p.PRPeriod)
    FROM PR_Period p (NOLOCK)
    WHERE p.Company = @cia
      AND p.PayRollType = @payrolltype
      AND LEFT(p.PRPeriod, 6) >= @inicio_yyyymm;

    IF @period_begin IS NULL
        RETURN 0;

    RETURN dbo.f_getPromedioVac(
        @cia,
        @person,
        @payrolltype,
        @process,
        @period_begin,
        @period_end,
        @concept,
        @valor_minimo,
        @divisor,
        @fechaingreso
    );
END
GO
