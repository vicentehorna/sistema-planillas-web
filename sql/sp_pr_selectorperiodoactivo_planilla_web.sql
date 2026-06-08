/*
    Periodo activo más reciente entre todos los procesos de una planilla.
    Usado por: GET /api/aperturar-periodos/periodo-sugerido
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodoactivo_planilla_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        LTRIM(RTRIM(pc.PRPeriod)) AS prperiod
    FROM PR_ProcessControl pc WITH (NOLOCK)
    WHERE pc.Company = @cia
      AND pc.PayRollType = @payrolltype
      AND pc.Status IN ('A', 'G')
    ORDER BY pc.PRPeriod DESC;
END
GO
