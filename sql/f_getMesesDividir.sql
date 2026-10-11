SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    Meses divisores (1 a 6) entre @FechaInicial y @FechaFinal.
    Usada por SP_PR_ReportePromedioLiquidacion.
*/
CREATE OR ALTER FUNCTION [dbo].[f_getMesesDividir]
(
    @FechaInicial DATE,
    @FechaFinal   DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @dias_falta INT;
    DECLARE @periodoini VARCHAR(20), @periodofin VARCHAR(20);

    SET @periodoini = CONVERT(VARCHAR(6), @FechaInicial, 112) + RIGHT(CONVERT(VARCHAR(6), @FechaInicial, 112), 2);
    SET @periodofin = CONVERT(VARCHAR(6), @FechaFinal, 112) + RIGHT(CONVERT(VARCHAR(6), @FechaFinal, 112), 2);

    SET @dias_falta = CASE
        WHEN @periodoini = @periodofin THEN 1
        ELSE CASE
            WHEN DATEDIFF(MONTH, @periodoini, @periodofin) > 0 THEN
                CASE WHEN DATEDIFF(MONTH, @periodoini, @periodofin) >= 5 THEN 6
                     ELSE DATEDIFF(MONTH, @periodoini, @periodofin) + 1 END
            ELSE 0
        END
    END;

    RETURN @dias_falta;
END
GO
