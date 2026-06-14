/*
    Alta de registro en PR_VacationDetail y PR_VacationPay;
    actualización de consumeddays en PR_Vacation.
    Usado por: POST /api/vacaciones/guardar-detalle (registro_vacaciones.html).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_guardar_detalle_web]
    @company       VARCHAR(4),
    @person        VARCHAR(20),
    @line          INT,
    @prperiod      VARCHAR(10),
    @datebegin     DATETIME,
    @dateend       DATETIME,
    @days          INT = NULL,
    @vacationtype  CHAR(1) = 'D',
    @xlastuser     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @secuence        INT;
    DECLARE @acquireddays    INT;
    DECLARE @consumeddays    INT;
    DECLARE @pendientes      INT;
    DECLARE @dias_nuevos     INT;
    DECLARE @replicationunit VARCHAR(4);

    IF @datebegin IS NULL OR @dateend IS NULL
    BEGIN
        RAISERROR('Indique fecha de inicio y término.', 16, 1);
        RETURN;
    END;

    IF @dateend < @datebegin
    BEGIN
        RAISERROR('La fecha de término no puede ser anterior a la de inicio.', 16, 1);
        RETURN;
    END;

    IF RTRIM(ISNULL(@prperiod, '')) = ''
    BEGIN
        RAISERROR('Seleccione el periodo de consumo efectivo.', 16, 1);
        RETURN;
    END;

    /* Normalizar y resolver periodo completo (YYYYMMDD) desde PR_Period. */
    DECLARE @prperiod_digits VARCHAR(10);
    DECLARE @prperiod_full   VARCHAR(10);

    SET @prperiod_digits = REPLACE(REPLACE(LTRIM(RTRIM(@prperiod)), '-', ''), '/', '');
    SET @prperiod_full = @prperiod_digits;

    IF LEN(@prperiod_digits) = 6 AND @prperiod_digits NOT LIKE '%[^0-9]%'
    BEGIN
        SELECT TOP 1 @prperiod_full = p.prperiod
        FROM PR_Period p
            INNER JOIN PR_Employee e
                ON e.company = @company
               AND e.person = @person
        WHERE p.company = @company
          AND p.payrolltype = e.payrolltype
          AND LEFT(p.prperiod, 6) = @prperiod_digits
        ORDER BY p.prperiod DESC;

        IF RTRIM(ISNULL(@prperiod_full, '')) = ''
        BEGIN
            SELECT TOP 1 @prperiod_full = prperiod
            FROM PR_Period
            WHERE company = @company
              AND LEFT(prperiod, 6) = @prperiod_digits
            ORDER BY prperiod DESC;
        END
    END
    ELSE IF LEN(@prperiod_digits) >= 8 AND @prperiod_digits NOT LIKE '%[^0-9]%'
    BEGIN
        SET @prperiod_full = LEFT(@prperiod_digits, 8);
    END;

    IF RTRIM(ISNULL(@prperiod_full, '')) = ''
       OR LEN(@prperiod_full) < 8
       OR @prperiod_full LIKE '%[^0-9]%'
    BEGIN
        RAISERROR('No se encontró el periodo de consumo efectivo en PR_Period.', 16, 1);
        RETURN;
    END;

    SET @prperiod = @prperiod_full;

    SET @vacationtype = UPPER(LTRIM(RTRIM(ISNULL(@vacationtype, 'D'))));
    IF @vacationtype NOT IN ('D', 'V', 'X') SET @vacationtype = 'D';

    SET @dias_nuevos = ISNULL(@days, DATEDIFF(DAY, @datebegin, @dateend) + 1);
    IF @dias_nuevos <= 0
    BEGIN
        RAISERROR('El rango de fechas debe generar al menos 1 día.', 16, 1);
        RETURN;
    END;

    SELECT
        @acquireddays = ISNULL(AcquiredDays, 0),
        @consumeddays = ISNULL(consumeddays, 0)
    FROM PR_Vacation
    WHERE company = @company
      AND person = @person
      AND line = @line;

    IF @acquireddays IS NULL
    BEGIN
        RAISERROR('No se encontró el periodo vacacional seleccionado.', 16, 1);
        RETURN;
    END;

    SET @pendientes = ABS(@consumeddays - @acquireddays);
    IF (@consumeddays + @dias_nuevos) > @acquireddays
    BEGIN
        RAISERROR('Los días solicitados superan el saldo pendiente del periodo (%d día(s)).', 16, 1, @pendientes);
        RETURN;
    END;

    SELECT @secuence = ISNULL(MAX(Secuence), 0) + 1
    FROM PR_VacationDetail
    WHERE company = @company
      AND person = @person
      AND line = @line;

    SELECT @replicationunit = ISNULL(ReplicationUnit, @company)
    FROM PR_Employee
    WHERE company = @company
      AND person = @person;

    INSERT INTO PR_VacationDetail (
        Person, Company, line, Secuence,
        prperiod, Datebegin, Dateend, Days,
        VacationType, ReplicationUnit, XLastUser, XLastDate
    )
    VALUES (
        @person, @company, @line, @secuence,
        @prperiod, @datebegin, @dateend, @dias_nuevos,
        @vacationtype, @replicationunit, @xlastuser, GETDATE()
    );

    INSERT INTO PR_VacationPay (
        Person, Company, line, Secuence,
        Datebegin, Dateend, Days, PRPeriod,
        VacationType, Status, ReplicationUnit,
        XLastUser, XLastDate
    )
    VALUES (
        @person, @company, @line, @secuence,
        @datebegin, @dateend, @dias_nuevos, @prperiod,
        @vacationtype, 'A', @replicationunit,
        @xlastuser, GETDATE()
    );

    UPDATE PR_Vacation
    SET consumeddays = (
            SELECT ISNULL(SUM(Days), 0)
            FROM PR_VacationDetail
            WHERE Person = @person
              AND Company = @company
              AND line = @line
        ),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE company = @company
      AND person = @person
      AND line = @line;

    SELECT
        @secuence AS secuence,
        @dias_nuevos AS dias,
        @pendientes - @dias_nuevos AS pendientes_restantes;
END
GO
