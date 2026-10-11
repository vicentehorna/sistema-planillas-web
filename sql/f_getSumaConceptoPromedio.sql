SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    Suma del concepto (por FormulaCode) en FIN_DE_MES del periodo @period, dentro del rango
    @FechaInicial..@FechaFinal. Usada por SP_PR_ReportePromedioLiquidacion (CTS y gratificación).
*/
CREATE OR ALTER FUNCTION [dbo].[f_getSumaConceptoPromedio]
(
    @FechaInicial DATE,
    @FechaFinal   DATE,
    @company      VARCHAR(4),
    @person       VARCHAR(20),
    @formulacode  VARCHAR(50),
    @period       VARCHAR(20)
)
RETURNS NUMERIC(19, 4)
AS
BEGIN
    DECLARE @dias_falta NUMERIC(19, 4);
    DECLARE @periodoini VARCHAR(20), @periodofin VARCHAR(20), @payrolltype VARCHAR(20);

    SET @payrolltype = (SELECT PayRollType FROM PR_Employee WHERE Person = @person AND Company = @company);

    SET @periodoini = CONVERT(VARCHAR(6), @FechaInicial, 112) + RIGHT(CONVERT(VARCHAR(6), @FechaInicial, 112), 2);
    SET @periodofin = CONVERT(VARCHAR(6), @FechaFinal, 112) + RIGHT(CONVERT(VARCHAR(6), @FechaFinal, 112), 2);

    SET @dias_falta = ISNULL((
        SELECT SUM(ISNULL(ConceptValueLo, ConceptValue))
        FROM PR_EmployeePayRollConcept
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND Person = @person
          AND ProcessType = (SELECT ProcessType FROM PR_ProcessType WHERE Company = @company AND ShortName = 'FIN_DE_MES')
          AND PRPeriod BETWEEN @periodoini AND @periodofin
          AND PRPeriod = @period
          AND EXISTS (
                SELECT * FROM PR_Concept
                WHERE Concept = PR_EmployeePayRollConcept.Concept
                  AND Company = @company
                  AND FormulaCode = @formulacode
          )
    ), 0);

    RETURN @dias_falta;
END
GO
