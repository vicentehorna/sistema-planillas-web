/*
    Ultimo periodo abierto del proceso Mensual / Fin de mes de una planilla.
    Usado por: GET /api/aperturar-periodos/periodo-sugerido
               (carga masiva, aperturar periodos, asignacion de conceptos)
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
    INNER JOIN PR_ProcessType pt WITH (NOLOCK)
        ON pt.ProcessType = pc.ProcessType
       AND pt.Company = pc.Company
    WHERE pc.Company = @cia
      AND pc.PayRollType = @payrolltype
      AND pc.Status IN ('A', 'G')
      AND (
            UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) IN ('FIN_DE_MES', 'MENSUAL')
         OR UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) LIKE '%FIN%MES%'
         OR UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) LIKE '%MENSUAL%'
      )
    ORDER BY pc.PRPeriod DESC;
END
GO

