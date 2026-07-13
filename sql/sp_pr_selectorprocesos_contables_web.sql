/*
    Selector de procesos contables (cálculo) por compañía.
    Misma lista de ShortName usada en procesamiento de planillas.
    Usado por: POST /api/asientos/configurar-conceptos/procesos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesos_contables_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(pt.ProcessType)) AS id,
        LTRIM(RTRIM(ISNULL(pt.Description, pt.ProcessType))) AS text,
        LTRIM(RTRIM(ISNULL(pt.ShortName, ''))) AS shortname
    FROM PR_ProcessType pt (NOLOCK)
    WHERE pt.Company = @cia
      AND pt.ShortName IN (
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
    ORDER BY pt.Description ASC, pt.ProcessType ASC;
END
GO
