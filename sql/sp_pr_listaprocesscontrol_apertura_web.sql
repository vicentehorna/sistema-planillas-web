/*
    Listado de control de procesos para apertura de periodos.
    Usado por: POST /api/aperturar-periodos/listado

    Basado en dw_pr_processcontrol_assign_list (PowerBuilder).
    @cia = Company (código corto, ej. BGT).
    @payrolltype = PayRollType (id planilla, ej. LIMABGT 000000000005).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listaprocesscontrol_apertura_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        pc.ProcessType AS processtype,
        pt.description AS description,
        pc.Company AS company,
        pc.PayRollType AS payrolltype,
        LTRIM(RTRIM(ISNULL(pc.PRPeriod, ''))) AS prperiod,
        pc.ProcessDate AS processdate,
        LTRIM(RTRIM(ISNULL(pc.Status, ''))) AS status,
        CASE LTRIM(RTRIM(ISNULL(pc.Status, '')))
            WHEN 'A' THEN 'Abierto'
            WHEN 'G' THEN 'Abierto'
            WHEN 'C' THEN 'Cerrado'
            WHEN 'P' THEN 'Pendiente'
            ELSE ''
        END AS statusdesc,
        'N' AS flag
    FROM PR_ProcessControl pc WITH (NOLOCK)
    INNER JOIN PR_PayRollTypeProcess ptp WITH (NOLOCK)
        ON pc.ProcessType = ptp.ProcessType
       AND pc.Company = ptp.Company
       AND pc.PayRollType = ptp.PayRollType
    INNER JOIN PR_ProcessType pt WITH (NOLOCK)
        ON pc.ProcessType = pt.ProcessType
    WHERE pc.Company = @cia
      AND pc.PayRollType = @payrolltype
      AND pc.Status IN ('A', 'G')

    UNION ALL

    SELECT
        ptp.ProcessType AS processtype,
        pt.description AS description,
        ptp.Company AS company,
        ptp.PayRollType AS payrolltype,
        '' AS prperiod,
        NULL AS processdate,
        '' AS status,
        'Sin control' AS statusdesc,
        'N' AS flag
    FROM PR_PayRollTypeProcess ptp WITH (NOLOCK)
    INNER JOIN PR_ProcessType pt WITH (NOLOCK)
        ON ptp.ProcessType = pt.ProcessType
    WHERE ptp.Company = @cia
      AND ptp.PayRollType = @payrolltype
      AND ptp.ProcessType NOT IN (
            SELECT pc2.ProcessType
            FROM PR_ProcessControl pc2 WITH (NOLOCK)
            WHERE pc2.Company = @cia
              AND pc2.PayRollType = @payrolltype
              AND pc2.Status IN ('A', 'G')
      )

    ORDER BY description;
END
GO
