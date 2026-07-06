/*
    SC_CTS: suma de un concepto en un proceso desde el inicio del ciclo de provisión CTS
    hasta @period_end. El ciclo depende del periodo en proceso (@period):
      - Mayo a Octubre  -> inicio Mayo del mismo año
      - Noviembre a Abril -> inicio Noviembre (año anterior si ene-abr)
    Si @period_end es anterior al periodo de inicio del ciclo, devuelve 0.
    Respeta fecha de ingreso/reingreso: no suma periodos anteriores al mes de alta.
*/
CREATE OR ALTER FUNCTION [dbo].[f_getSumaConceptosCTS](
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
    DECLARE @period_begin     VARCHAR(20);
    DECLARE @inicio_ciclo_cts DATE;
    DECLARE @inicio_yyyymm    CHAR(6);
    DECLARE @mes_periodo      INT;
    DECLARE @order_ini        INT;
    DECLARE @order_fin        INT;
    DECLARE @fechaingreso     DATETIME;
    DECLARE @hire_yyyymm      CHAR(6);
    DECLARE @period_hire      VARCHAR(20);
    DECLARE @order_hire       INT;

    IF ISNULL(LTRIM(RTRIM(@concept)), '') = ''
        RETURN 0;

    IF @period IS NULL OR @period_end IS NULL
        RETURN 0;

    SET @mes_periodo = CONVERT(INT, SUBSTRING(@period, 5, 2));

    SET @inicio_ciclo_cts = CASE
        WHEN @mes_periodo BETWEEN 5 AND 10 THEN CONVERT(DATE, LEFT(@period, 4) + '0501')
        WHEN @mes_periodo BETWEEN 11 AND 12 THEN CONVERT(DATE, LEFT(@period, 4) + '1101')
        ELSE CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101')
    END;

    SET @inicio_yyyymm = LEFT(CONVERT(VARCHAR(8), @inicio_ciclo_cts, 112), 6);

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

    SELECT @fechaingreso = ISNULL(e.ReEntryDate, e.EntryDate)
    FROM PR_Employee e (NOLOCK)
    WHERE e.Company = @cia
      AND e.Person = @person;

    IF @fechaingreso IS NOT NULL
    BEGIN
        SET @hire_yyyymm = LEFT(CONVERT(VARCHAR(8), CONVERT(DATE, @fechaingreso), 112), 6);

        SELECT @period_hire = MIN(p.PRPeriod)
        FROM PR_Period p (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype
          AND LEFT(p.PRPeriod, 6) >= @hire_yyyymm;

        IF @period_hire IS NOT NULL
        BEGIN
            SELECT @order_hire = PeriodOrder
            FROM PR_Period (NOLOCK)
            WHERE Company = @cia
              AND PayRollType = @payrolltype
              AND PRPeriod = @period_hire;

            IF ISNULL(@order_hire, 0) > ISNULL(@order_ini, 0)
            BEGIN
                SET @period_begin = @period_hire;
                SET @order_ini = @order_hire;
            END
        END
    END

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
