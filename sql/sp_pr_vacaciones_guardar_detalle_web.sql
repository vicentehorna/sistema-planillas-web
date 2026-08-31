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
    DECLARE @pendientes      DECIMAL(10, 2);
    DECLARE @adquiridos_ganados DECIMAL(10, 2);
    DECLARE @dias_nuevos     INT;
    DECLARE @replicationunit VARCHAR(4);
    DECLARE @fecha_hoy       DATE = CAST(GETDATE() AS DATE);
    DECLARE @dias_vacaciones DECIMAL(10, 2);
    DECLARE @inicio_provision DATE;
    DECLARE @inicio_derecho  DATE;

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
        @consumeddays = ISNULL(consumeddays, 0),
        @inicio_provision = CAST(DateBeginProvision AS DATE),
        @inicio_derecho = CAST(DateBeginRights AS DATE)
    FROM PR_Vacation
    WHERE company = @company
      AND person = @person
      AND line = @line;

    IF @acquireddays IS NULL
    BEGIN
        RAISERROR('No se encontró el periodo vacacional seleccionado.', 16, 1);
        RETURN;
    END;

    SELECT @dias_vacaciones = CAST(ISNULL(pt.DiasVacaciones, 30) AS DECIMAL(10, 2))
    FROM PR_Employee e
        INNER JOIN PR_PayRollType pt
            ON pt.Company = e.Company
           AND pt.PayRollType = e.PayRollType
    WHERE e.Company = @company
      AND e.Person = @person;

    IF @dias_vacaciones IS NULL OR @dias_vacaciones <= 0
        SET @dias_vacaciones = 30;

    SET @adquiridos_ganados = CASE
        WHEN @inicio_provision > @fecha_hoy THEN 0
        WHEN @inicio_derecho <= @fecha_hoy THEN CAST(@acquireddays AS DECIMAL(10, 2))
        ELSE ROUND(dbo.f_getDias360(@inicio_provision, @fecha_hoy) * @dias_vacaciones / 360.0, 2)
    END;

    SET @pendientes = @adquiridos_ganados - CAST(@consumeddays AS DECIMAL(10, 2));
    IF @pendientes < 0
        SET @pendientes = 0;

    IF (CAST(@consumeddays AS DECIMAL(10, 2)) + @dias_nuevos) > @adquiridos_ganados
    BEGIN
        RAISERROR('Los días solicitados superan el saldo pendiente del periodo.', 16, 1);
        RETURN;
    END;

    /* Siguiente Secuence = MAX(Detail, Pay) + 1.
       En datos migrados pueden diferir los correlativos entre ambas tablas. */
    SELECT @secuence = ISNULL(MAX(sec), 0) + 1
    FROM (
        SELECT Secuence AS sec
        FROM PR_VacationDetail
        WHERE company = @company
          AND person = @person
          AND line = @line
        UNION ALL
        SELECT Secuence AS sec
        FROM PR_VacationPay
        WHERE company = @company
          AND person = @person
          AND line = @line
    ) s;

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
