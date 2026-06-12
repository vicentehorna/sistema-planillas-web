/*
    Selector de procesos por compañía y tipo de planilla.
    Usado por: GET /api/selectores/procesos (reportes, procesar planilla, etc.).

    id: processtype
    text: proceso (PR_ProcessType.Description)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesos_web]
    @cia VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        PTP.ProcessType AS processtype,
        PTP.PayRollType AS payrolltype,
        PTP.Company AS company,
        PT.Description AS proceso
    FROM PR_PayRollTypeProcess PTP (NOLOCK)
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PTP.ProcessType = PT.ProcessType
           AND PTP.Company = PT.Company
    WHERE PTP.Company = @cia
      AND PTP.PayRollType = @payrolltype
    ORDER BY PT.Description ASC;
END
GO
