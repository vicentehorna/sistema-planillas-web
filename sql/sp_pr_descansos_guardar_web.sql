/*
    Alta / edición de descanso médico en PR_EmployeeMedicalRest.
    Usado por: POST /descansos/guardar (registro_descansos_medicos.html).

    @line NULL o <= 0 → alta (INSERT).
    @line > 0 → actualización del registro existente.

    @medicalresttype — código de PR_MedicalRestType (filtrado por compañía).
    Si el tipo tiene PDT 20 y los días empleador acumulados del año + días nuevos
    (excluyendo el propio @line en edición) superan 20, fuerza cobertura EsSalud
    (PayReponsableFlag = S, PDT 21) y exige CITT.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_descansos_guardar_web]
    @company          VARCHAR(4),
    @person           VARCHAR(20),
    @datebegin        DATETIME,
    @dateend          DATETIME,
    @medicalresttype  VARCHAR(20),
    @prperiod         VARCHAR(10) = NULL,
    @citt             VARCHAR(20) = NULL,
    @cmp_medico       VARCHAR(255) = NULL,
    @adjunto          VARCHAR(255) = NULL,
    @days             INT = NULL,
    @line             INT = NULL,
    @xlastuser        VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @dias_nuevos       INT;
    DECLARE @anio              INT;
    DECLARE @dias_empleador    INT;
    DECLARE @pay_flag          CHAR(1);
    DECLARE @pdt               VARCHAR(2);
    DECLARE @replicationunit   VARCHAR(4);
    DECLARE @yyyymm            VARCHAR(6);
    DECLARE @cobertura_forzada BIT = 0;
    DECLARE @es_edicion        BIT = 0;

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

    SET @medicalresttype = LTRIM(RTRIM(ISNULL(@medicalresttype, '')));
    IF @medicalresttype = ''
    BEGIN
        RAISERROR('Seleccione el tipo de descanso.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@line, 0) > 0
    BEGIN
        SET @es_edicion = 1;
        IF NOT EXISTS (
            SELECT 1
            FROM PR_EmployeeMedicalRest
            WHERE Company = @company
              AND Person = @person
              AND line = @line
        )
        BEGIN
            RAISERROR('No se encontró el registro de descanso médico a editar.', 16, 1);
            RETURN;
        END;
    END;

    SELECT @pdt = LTRIM(RTRIM(mrt.PDT))
    FROM PR_MedicalRestType mrt
    WHERE mrt.Company = @company
      AND mrt.MedicalRestType = @medicalresttype;

    IF RTRIM(ISNULL(@pdt, '')) = ''
    BEGIN
        RAISERROR('Tipo de descanso no válido para la compañía.', 16, 1);
        RETURN;
    END;

    SET @dias_nuevos = ISNULL(@days, DATEDIFF(DAY, @datebegin, @dateend) + 1);
    IF @dias_nuevos <= 0
    BEGIN
        RAISERROR('El rango de fechas debe generar al menos 1 día.', 16, 1);
        RETURN;
    END;

    SET @anio = YEAR(@datebegin);

    SELECT @dias_empleador = ISNULL(SUM(emr.Days), 0)
    FROM PR_EmployeeMedicalRest emr
        INNER JOIN PR_MedicalRestType mrt
            ON mrt.MedicalRestType = emr.MedicalRestType
           AND mrt.Company = emr.Company
    WHERE emr.Company = @company
      AND emr.Person = @person
      AND emr.PayReponsableFlag = 'E'
      AND LTRIM(RTRIM(ISNULL(mrt.PDT, ''))) = '20'
      AND YEAR(emr.DateBegin) = @anio
      AND (@es_edicion = 0 OR emr.line <> @line);

    IF @pdt = '20' AND (@dias_empleador + @dias_nuevos) > 20
    BEGIN
        SET @pay_flag = 'S';
        SET @cobertura_forzada = 1;

        IF RTRIM(ISNULL(@citt, '')) = ''
        BEGIN
            RAISERROR('Al superar los 20 días a cargo del empleador se requiere el número de CITT para el subsidio EsSalud.', 16, 1);
            RETURN;
        END;

        SELECT TOP 1 @medicalresttype = mrt.MedicalRestType
        FROM PR_MedicalRestType mrt
        WHERE mrt.Company = @company
          AND LTRIM(RTRIM(mrt.PDT)) = '21'
        ORDER BY mrt.MedicalRestType;

        IF RTRIM(ISNULL(@medicalresttype, '')) = ''
        BEGIN
            RAISERROR('No se encontró el tipo de descanso médico (PDT 21) para el subsidio EsSalud.', 16, 1);
            RETURN;
        END;

        SET @pdt = '21';
    END
    ELSE IF @pdt IN ('21', '22')
    BEGIN
        SET @pay_flag = 'S';
    END
    ELSE
    BEGIN
        SET @pay_flag = 'E';
    END;

    SET @prperiod = LTRIM(RTRIM(ISNULL(@prperiod, '')));

    IF @prperiod = ''
    BEGIN
        SET @yyyymm = CONVERT(VARCHAR(6), @datebegin, 112);

        SELECT TOP 1 @prperiod = p.PRPeriod
        FROM PR_Period p
            INNER JOIN PR_Employee e
                ON e.Company = @company
               AND e.Person = @person
        WHERE p.Company = @company
          AND p.PayRollType = e.PayRollType
          AND LEFT(p.PRPeriod, 6) = @yyyymm
        ORDER BY p.PRPeriod DESC;

        IF RTRIM(ISNULL(@prperiod, '')) = ''
        BEGIN
            SELECT TOP 1 @prperiod = p.PRPeriod
            FROM PR_Period p
            WHERE p.Company = @company
              AND LEFT(p.PRPeriod, 6) = @yyyymm
            ORDER BY p.PRPeriod DESC;
        END;

        IF RTRIM(ISNULL(@prperiod, '')) = ''
            SET @prperiod = CONVERT(VARCHAR(8), @datebegin, 112);
    END;

    IF @es_edicion = 1
    BEGIN
        UPDATE PR_EmployeeMedicalRest
        SET MedicalRestType = @medicalresttype,
            DateBegin = @datebegin,
            DateEnd = @dateend,
            Days = @dias_nuevos,
            PRPeriod = @prperiod,
            PayReponsableFlag = @pay_flag,
            XLastUser = @xlastuser,
            XLastDate = GETDATE(),
            citt = NULLIF(LTRIM(RTRIM(@citt)), ''),
            pdt = @pdt,
            medico = NULLIF(LTRIM(RTRIM(@cmp_medico)), ''),
            adjunto = CASE
                WHEN @adjunto IS NULL THEN adjunto
                WHEN LTRIM(RTRIM(@adjunto)) = '' THEN NULL
                ELSE @adjunto
            END
        WHERE Company = @company
          AND Person = @person
          AND line = @line;
    END
    ELSE
    BEGIN
        SELECT @line = ISNULL(MAX(line), 0) + 1
        FROM PR_EmployeeMedicalRest
        WHERE Company = @company
          AND Person = @person;

        SELECT @replicationunit = ISNULL(ReplicationUnit, @company)
        FROM PR_Employee
        WHERE Company = @company
          AND Person = @person;

        INSERT INTO PR_EmployeeMedicalRest (
            Person, Company, line,
            MedicalRestType, DateBegin, DateEnd, Days,
            PRPeriod, PayReponsableFlag, Status,
            CostCenter, CostCenterCode,
            ReplicationUnit, XLastUser, XLastDate,
            citt, pdt, medico, adjunto
        )
        VALUES (
            @person, @company, @line,
            @medicalresttype, @datebegin, @dateend, @dias_nuevos,
            @prperiod, @pay_flag, 'P',
            NULL, NULL,
            @replicationunit, @xlastuser, GETDATE(),
            NULLIF(LTRIM(RTRIM(@citt)), ''),
            @pdt,
            NULLIF(LTRIM(RTRIM(@cmp_medico)), ''),
            NULLIF(LTRIM(RTRIM(@adjunto)), '')
        );
    END;

    SELECT
        @line AS line,
        @dias_nuevos AS dias,
        @pay_flag AS payreponsableflag,
        @pdt AS pdt,
        @medicalresttype AS medicalresttype,
        @cobertura_forzada AS cobertura_forzada,
        @es_edicion AS es_edicion,
        CASE @pay_flag
            WHEN 'E' THEN 'Empleador'
            WHEN 'S' THEN 'Subsidio EsSalud'
            ELSE @pay_flag
        END AS cobertura_texto;
END
GO
