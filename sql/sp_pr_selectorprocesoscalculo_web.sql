/*
    Selector de procesos de cálculo por compañía y tipo de planilla.
    Filtra procesos habilitados en PR_WindowProcess y shortname de cálculo.
    Usado por: POST /api/procesar-planilla/procesos-calculo (procesar_planilla.html).

    processtype, payrolltype, company, description
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesoscalculo_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT DISTINCT
        PTP.ProcessType AS processtype,
        PTP.PayRollType AS payrolltype,
        PTP.Company AS company,
        PT.Description AS description
    FROM PR_PayRollTypeProcess PTP (NOLOCK)
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PTP.ProcessType = PT.ProcessType
           AND PTP.Company = PT.Company
        INNER JOIN PR_WindowProcess WP (NOLOCK)
            ON WP.ProcessType = PT.ProcessType
    WHERE PTP.Company = @cia
      AND PTP.PayRollType = @payrolltype
      AND PT.ShortName IN (
            'CTS',
            'FIN_DE_MES',
            'GRATIFICACION',
            'LIQUIDACION',
            'VACACIONES',
            'QUINCENA',
            'PROVISION_CTS',
            'PROVISION_VACACIONES',
            'PROVISION_GRATIF'
        )
    ORDER BY PT.Description ASC;
END
GO
