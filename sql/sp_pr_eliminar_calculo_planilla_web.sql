/*
    Elimina el cálculo de planilla de un trabajador para compañía, tipo, proceso y periodo.
    Equivalente web al proceso legacy de PowerBuilder (eliminar cálculo).
    Usado por: POST /api/procesar-planilla/eliminar-calculo (procesar_planilla.html).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_calculo_planilla_web]
    @company     VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(10),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    IF @company = '' OR @payrolltype = '' OR @processtype = '' OR @period = ''
    BEGIN
        RAISERROR('Faltan compañía, tipo de planilla, proceso o periodo.', 16, 1);
        RETURN;
    END;

    IF @person = ''
    BEGIN
        RAISERROR('Debe seleccionar un trabajador.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM PR_IntegralProcessLog
        WHERE Company = @company
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_EMPLOYEEAFP
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_EmployeePayRollConcept
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND ProcessType = @processtype
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_EmployeePayRoll
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND ProcessType = @processtype
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_LOG_CALCULO_PLANILLAS
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND Process = @processtype
          AND Period = @period
          AND Person = @person;

        DELETE FROM PR_PayrollLog
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND ProcessType = @processtype
          AND PRPeriod = @period
          AND Person = @person;

        COMMIT TRANSACTION;

        SELECT 1 AS ok, @person AS person;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH;
END
GO
