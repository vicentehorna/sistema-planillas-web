/*
    Alta / edición de periodo de planilla (PR_Period).
    Usado por: POST /api/tipos-planilla/periodos/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarperiodo_payrolltype_web]
    @modo         CHAR(1),
    @company      VARCHAR(4),
    @payrolltype  VARCHAR(20),
    @prperiod     VARCHAR(10),
    @datebegin    VARCHAR(10) = NULL,
    @dateend      VARCHAR(10) = NULL,
    @cadatebegin  VARCHAR(10) = NULL,
    @cadateend    VARCHAR(10) = NULL,
    @xlastuser    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @prperiod_norm   VARCHAR(10);
    DECLARE @datebegin_dt    DATETIME;
    DECLARE @dateend_dt      DATETIME;
    DECLARE @cadatebegin_dt  DATETIME;
    DECLARE @cadateend_dt    DATETIME;
    DECLARE @periodorder     INT;
    DECLARE @glperiod        VARCHAR(6);

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @prperiod = LTRIM(RTRIM(ISNULL(@prperiod, '')));
    SET @datebegin = NULLIF(LTRIM(RTRIM(ISNULL(@datebegin, ''))), '');
    SET @dateend = NULLIF(LTRIM(RTRIM(ISNULL(@dateend, ''))), '');
    SET @cadatebegin = NULLIF(LTRIM(RTRIM(ISNULL(@cadatebegin, ''))), '');
    SET @cadateend = NULLIF(LTRIM(RTRIM(ISNULL(@cadateend, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    SET @prperiod_norm = REPLACE(REPLACE(@prperiod, '-', ''), '/', '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @company = '' OR @payrolltype = '' OR @prperiod_norm = ''
    BEGIN
        RAISERROR('Indique compañía, tipo de planilla y periodo.', 16, 1);
        RETURN;
    END;

    IF LEN(@prperiod_norm) <> 8 OR ISNUMERIC(@prperiod_norm) = 0
    BEGIN
        RAISERROR('El periodo debe tener 8 dígitos (formato YYYYMMDD).', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_PayRollType (NOLOCK)
        WHERE Company = @company
          AND PayRollType = @payrolltype
    )
    BEGIN
        RAISERROR('Tipo de planilla no encontrado para la compañía.', 16, 1);
        RETURN;
    END;

    IF @datebegin IS NULL OR @dateend IS NULL
    BEGIN
        RAISERROR('Indique fecha de inicio y fin del periodo.', 16, 1);
        RETURN;
    END;

    IF ISDATE(@datebegin) = 0 OR ISDATE(@dateend) = 0
    BEGIN
        RAISERROR('Fechas de inicio o fin no válidas.', 16, 1);
        RETURN;
    END;

    SET @datebegin_dt = CONVERT(DATETIME, @datebegin, 120);
    SET @dateend_dt = CONVERT(DATETIME, @dateend, 120);

    IF @cadatebegin IS NOT NULL AND ISDATE(@cadatebegin) = 0
    BEGIN
        RAISERROR('Fecha de inicio CA no válida.', 16, 1);
        RETURN;
    END;

    IF @cadateend IS NOT NULL AND ISDATE(@cadateend) = 0
    BEGIN
        RAISERROR('Fecha de fin CA no válida.', 16, 1);
        RETURN;
    END;

    SET @cadatebegin_dt = CASE
        WHEN @cadatebegin IS NULL THEN @datebegin_dt
        ELSE CONVERT(DATETIME, @cadatebegin, 120)
    END;
    SET @cadateend_dt = CASE
        WHEN @cadateend IS NULL THEN @dateend_dt
        ELSE CONVERT(DATETIME, @cadateend, 120)
    END;

    SET @glperiod = LEFT(@prperiod_norm, 6);

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM PR_Period (NOLOCK)
            WHERE Company = @company
              AND PayRollType = @payrolltype
              AND PRPeriod = @prperiod_norm
        )
        BEGIN
            RAISERROR('Ya existe el periodo indicado para este tipo de planilla.', 16, 1);
            RETURN;
        END;

        SELECT @periodorder = ISNULL(MAX(PeriodOrder), 0) + 1
        FROM PR_Period (NOLOCK)
        WHERE Company = @company
          AND PayRollType = @payrolltype;

        INSERT INTO PR_Period (
            PayRollType,
            PRPeriod,
            GLPeriod,
            PeriodOrder,
            DateBegin,
            DateEnd,
            CADateBegin,
            CADateEnd,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate
        )
        VALUES (
            @payrolltype,
            @prperiod_norm,
            @glperiod,
            @periodorder,
            @datebegin_dt,
            @dateend_dt,
            @cadatebegin_dt,
            @cadateend_dt,
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE()
        );

        SELECT
            @prperiod_norm AS prperiod,
            'Periodo registrado correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Period (NOLOCK)
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND PRPeriod = @prperiod_norm
    )
    BEGIN
        RAISERROR('No se encontró el periodo a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE PR_Period
    SET DateBegin = @datebegin_dt,
        DateEnd = @dateend_dt,
        CADateBegin = @cadatebegin_dt,
        CADateEnd = @cadateend_dt,
        GLPeriod = @glperiod,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND PayRollType = @payrolltype
      AND PRPeriod = @prperiod_norm;

    SELECT
        @prperiod_norm AS prperiod,
        'Periodo actualizado correctamente.' AS mensaje;
END
GO
