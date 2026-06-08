/*
    Apertura de periodo para un tipo de proceso (lógica Useroption1 PowerBuilder).
    Usado por: POST /api/aperturar-periodos/aperturar (una llamada por proceso seleccionado).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_aperturarperiodo_proceso_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia, ''))), 4);
    SET @payrolltype = LEFT(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), 20);
    SET @processtype = LEFT(LTRIM(RTRIM(ISNULL(@processtype, ''))), 20);
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 10);
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), 20);

    IF @cia = '' OR @payrolltype = '' OR @processtype = '' OR @period = ''
    BEGIN
        RAISERROR('Faltan parámetros para aperturar el periodo.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Period p WITH (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype
          AND LTRIM(RTRIM(p.PRPeriod)) = @period
    )
    BEGIN
        RAISERROR('No existe el periodo configurado para el tipo de planilla seleccionado.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_PayRollTypeProcess ptp WITH (NOLOCK)
        WHERE ptp.Company = @cia
          AND ptp.PayRollType = @payrolltype
          AND ptp.ProcessType = @processtype
    )
    BEGIN
        RAISERROR('El tipo de proceso no está configurado para la planilla.', 16, 1);
        RETURN;
    END;

    DECLARE @replicationunit VARCHAR(4) = '';

    SELECT TOP 1
        @replicationunit = LEFT(NULLIF(LTRIM(RTRIM(pc.ReplicationUnit)), ''), 4)
    FROM PR_ProcessControl pc WITH (NOLOCK)
    WHERE pc.Company = @cia
      AND pc.PayRollType = @payrolltype
      AND pc.ProcessType = @processtype;

    IF @replicationunit IS NULL
        SET @replicationunit = '';

    IF NOT EXISTS (
        SELECT 1
        FROM PR_ProcessControl pc WITH (NOLOCK)
        WHERE pc.Company = @cia
          AND pc.PayRollType = @payrolltype
          AND pc.ProcessType = @processtype
    )
    BEGIN
        INSERT INTO PR_ProcessControl (
            PayRollType, ProcessType, PRPeriod, Status,
            PaymentDate, ProcessDate, Company, ReplicationUnit,
            XLastUser, XLastDate
        )
        SELECT
            @payrolltype,
            @processtype,
            LEFT(LTRIM(RTRIM(p.PRPeriod)), 10),
            CASE
                WHEN LTRIM(RTRIM(p.PRPeriod)) < @period THEN 'C'
                WHEN LTRIM(RTRIM(p.PRPeriod)) > @period THEN 'P'
                ELSE 'A'
            END,
            NULL,
            CASE WHEN LTRIM(RTRIM(p.PRPeriod)) = @period THEN GETDATE() ELSE NULL END,
            @cia,
            LEFT(ISNULL(NULLIF(LTRIM(RTRIM(p.ReplicationUnit)), ''), @replicationunit), 4),
            @xlastuser,
            GETDATE()
        FROM PR_Period p WITH (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype;
        RETURN;
    END;

    UPDATE PR_ProcessControl
    SET Status = 'C',
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND LTRIM(RTRIM(PRPeriod)) < @period;

    UPDATE PR_ProcessControl
    SET Status = 'P',
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND LTRIM(RTRIM(PRPeriod)) > @period;

    UPDATE PR_ProcessControl
    SET Status = 'A',
        PRPeriod = @period,
        ProcessDate = GETDATE(),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND LTRIM(RTRIM(PRPeriod)) = @period;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO PR_ProcessControl (
            PayRollType, ProcessType, PRPeriod, Status,
            PaymentDate, ProcessDate, Company, ReplicationUnit,
            XLastUser, XLastDate
        )
        VALUES (
            @payrolltype, @processtype, @period, 'A',
            NULL, GETDATE(), @cia, @replicationunit,
            @xlastuser, GETDATE()
        );
    END;
END
GO
