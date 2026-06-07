/*
    Periodo activo del proceso (PR_ProcessControl, Status = 'A').
    Usado por: GET /api/selectores/periodo-activo (reporte resumen total y similares).

    Parámetros:
      @cia, @payrolltype, @processtype — obligatorios.

    Retorna una fila con prperiod o vacío si no hay periodo activo.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodoactivo_web]
    @cia         VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        LTRIM(RTRIM(PRPeriod)) AS prperiod
    FROM PR_ProcessControl
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND Status = 'A'
    ORDER BY PRPeriod DESC;
END
GO
