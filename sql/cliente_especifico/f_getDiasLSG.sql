/*
  Genérico multi-cliente: f_getDiasLSG
  Suma días de licencia sin goce en FIN_DE_MES entre @FechaInicial y @FechaFinal.

  FormulaCodes de DÍAS (no horas ni importes) usados en distintos clientes:
    - DIASLICSGOCE
    - DIAS_LIC_SINGOCE
    - DIASLICSINGOCE
    - DIASSINGOCE
    - DIAS_LICENCIA_SIN_GO
*/
CREATE OR ALTER FUNCTION [dbo].[f_getDiasLSG]
(
    @FechaInicial DATE,
    @FechaFinal DATE,
    @company varchar(20),
    @person varchar(20)
)
RETURNS INT
AS
BEGIN
    DECLARE @dias_falta int
    DECLARE @periodoini varchar(20), @periodofin varchar(20), @payrolltype varchar(20)

    SET @payrolltype = (
        SELECT TOP 1 PayRollType
        FROM PR_Employee
        WHERE Person = @person AND Company = @company
    )

    SET @periodoini = CONVERT(varchar(6), @FechaInicial, 112)
                    + RIGHT(CONVERT(varchar(6), @FechaInicial, 112), 2)
    SET @periodofin = CONVERT(varchar(6), @FechaFinal, 112)
                    + RIGHT(CONVERT(varchar(6), @FechaFinal, 112), 2)

    SET @dias_falta = ISNULL((
        SELECT SUM(ISNULL(ConceptValueLo, CONCEPTVALUE))
        FROM PR_EmployeePayRollConcept
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND Person = @person
          AND ProcessType = (
                SELECT TOP 1 ProcessType
                FROM PR_ProcessType
                WHERE Company = @company AND ShortName = 'FIN_DE_MES'
          )
          AND PRPeriod BETWEEN @periodoini AND @periodofin
          AND EXISTS (
                SELECT 1
                FROM PR_Concept
                WHERE Concept = PR_EmployeePayRollConcept.Concept
                  AND Company = @company
                  AND UPPER(LTRIM(RTRIM(FormulaCode))) IN (
                        'DIASLICSGOCE',
                        'DIAS_LIC_SINGOCE',
                        'DIASLICSINGOCE',
                        'DIASSINGOCE',
                        'DIAS_LICENCIA_SIN_GO'
                  )
          )
    ), 0)

    RETURN @dias_falta
END
GO
