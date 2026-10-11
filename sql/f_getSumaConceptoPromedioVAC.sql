SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    Igual que f_getSumaConceptoPromedio, para vacaciones: si @period es el mes de control
    (cese - 5 meses), suma desde @FechaInicial hasta ese mes de control.
    Usada por SP_PR_ReportePromedioLiquidacion.
*/
CREATE OR ALTER FUNCTION [dbo].[f_getSumaConceptoPromedioVAC]
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
    DECLARE @periodocontrol VARCHAR(20), @flag CHAR(1);

    SET @periodocontrol = CONVERT(VARCHAR(6), DATEADD(MONTH, -5, (SELECT CeaseDate FROM PR_Employee WHERE Person = @person AND Company = @company)), 112);
    SET @flag = 'N';
    IF LEFT(@period, 6) = LEFT(@periodocontrol, 6) SET @flag = 'Y';

    SET @periodocontrol = @periodocontrol + RIGHT(@periodocontrol, 2);

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
          AND PRPeriod BETWEEN @periodoini AND (CASE WHEN @flag = 'Y' THEN @periodocontrol ELSE @periodofin END)
          AND ((@flag = 'N' AND PRPeriod = @period) OR (@flag = 'Y'))
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
