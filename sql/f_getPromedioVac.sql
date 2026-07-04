/*
    Promedio Vac: promedio de un concepto en un proceso y rango de periodos.
    Suma los importes de cada mes del rango completo.
    Divide entre @divisor si > 0; si no, entre meses del rango desde ingreso/reingreso.
    Si menos de @valor_minimo meses tienen importe > 0, devuelve 0.
*/
CREATE OR ALTER FUNCTION [dbo].[f_getPromedioVac](
    @cia           VARCHAR(20),
    @person        VARCHAR(20),
    @payrolltype   VARCHAR(20),
    @process       VARCHAR(20),
    @period_begin  VARCHAR(20),
    @period_end    VARCHAR(20),
    @concept       VARCHAR(20),
    @valor_minimo  NUMERIC(19, 4),
    @divisor       NUMERIC(19, 4) = NULL,
    @fechaingreso  DATETIME = NULL
)
RETURNS NUMERIC(19, 4)
AS
BEGIN
    DECLARE @suma            NUMERIC(19, 4);
    DECLARE @meses_positivos INT;
    DECLARE @meses_divisor   INT;
    DECLARE @hire_yyyymm     CHAR(6);

    IF ISNULL(LTRIM(RTRIM(@concept)), '') = ''
        RETURN 0;

    IF @period_begin IS NULL OR @period_end IS NULL
        RETURN 0;

    SELECT
        @suma = SUM(ISNULL(epc.importe, 0)),
        @meses_positivos = SUM(CASE WHEN ISNULL(epc.importe, 0) > 0 THEN 1 ELSE 0 END)
    FROM PR_Period p (NOLOCK)
        LEFT JOIN (
            SELECT
                e.PRPeriod,
                ISNULL(e.ConceptValueLo, e.ConceptValue) AS importe
            FROM PR_EmployeePayRollConcept e (NOLOCK)
            WHERE e.Company = @cia
              AND e.PayRollType = @payrolltype
              AND e.Person = @person
              AND e.ProcessType = @process
              AND e.Concept = @concept
        ) epc ON epc.PRPeriod = p.PRPeriod
    WHERE p.Company = @cia
      AND p.PayRollType = @payrolltype
      AND p.PRPeriod BETWEEN @period_begin AND @period_end;

    IF ISNULL(@meses_positivos, 0) < ISNULL(@valor_minimo, 0)
        RETURN 0;

    IF ISNULL(@divisor, 0) > 0
    BEGIN
        SET @meses_divisor = CONVERT(INT, @divisor);
    END
    ELSE
    BEGIN
        IF @fechaingreso IS NOT NULL
            SET @hire_yyyymm = LEFT(CONVERT(VARCHAR(8), CONVERT(DATE, @fechaingreso), 112), 6);
        ELSE
            SET @hire_yyyymm = NULL;

        SELECT @meses_divisor = COUNT(*)
        FROM PR_Period p (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype
          AND p.PRPeriod BETWEEN @period_begin AND @period_end
          AND (
                @hire_yyyymm IS NULL
                OR LEFT(p.PRPeriod, 6) >= @hire_yyyymm
              );
    END

    IF ISNULL(@meses_divisor, 0) = 0
        RETURN 0;

    RETURN ISNULL(@suma, 0) / @meses_divisor;
END
GO
