/*
    Cierra el periodo activo de un tipo de proceso (Status A/G → C).
    Usado por: POST /api/aperturar-periodos/cerrar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_cerrarperiodo_proceso_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia, ''))), 4);
    SET @payrolltype = LEFT(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), 20);
    SET @processtype = LEFT(LTRIM(RTRIM(ISNULL(@processtype, ''))), 20);
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), 20);

    IF @cia = '' OR @payrolltype = '' OR @processtype = ''
    BEGIN
        RAISERROR('Faltan parámetros para cerrar el periodo.', 16, 1);
        RETURN;
    END;

    UPDATE PR_ProcessControl
    SET Status = 'C',
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND Status IN ('A', 'G');
END
GO
