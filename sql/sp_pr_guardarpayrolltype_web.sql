/*
    Alta / edición de PR_PayRollType — maestro web Tipo de Planillas.
    Usado por: POST /api/tipos-planilla/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarpayrolltype_web]
    @modo        CHAR(1),
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20) = NULL,
    @shortname   VARCHAR(20),
    @description VARCHAR(50),
    @diasvacaciones INT = 30,
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @tipo_nuevo      VARCHAR(20);
    DECLARE @periodtype      VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = NULLIF(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), '');
    SET @shortname = UPPER(LTRIM(RTRIM(ISNULL(@shortname, ''))));
    SET @description = UPPER(LTRIM(RTRIM(ISNULL(@description, ''))));
    SET @diasvacaciones = ISNULL(@diasvacaciones, 30);
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @shortname = '' OR @description = ''
    BEGIN
        RAISERROR('Indique el nombre corto y la descripción del tipo de planilla.', 16, 1);
        RETURN;
    END;

    IF @diasvacaciones < 0 OR @diasvacaciones > 365
    BEGIN
        RAISERROR('Los días de vacaciones deben estar entre 0 y 365.', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @payrolltype IS NULL
    BEGIN
        RAISERROR('Indique el tipo de planilla a actualizar.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM PR_PayRollType (NOLOCK)
            WHERE Company = @company
              AND LTRIM(RTRIM(ISNULL(ShortName, ''))) = @shortname
        )
        BEGIN
            RAISERROR('Ya existe un tipo de planilla con el mismo nombre corto para la compañía.', 16, 1);
            RETURN;
        END;

        SELECT TOP 1 @periodtype = PeriodType
        FROM PR_PeriodType (NOLOCK)
        WHERE Company = @company
        ORDER BY
            CASE WHEN LTRIM(RTRIM(ISNULL(Description, ''))) = 'Mensual' THEN 0 ELSE 1 END,
            PeriodType ASC;

        IF @periodtype IS NULL
        BEGIN
            RAISERROR('No existe tipo de periodo configurado para la compañía.', 16, 1);
            RETURN;
        END;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'PR_PAYROLLTYPE',
            @xlastuser = @xlastuser;

        SELECT @tipo_nuevo = id_generado FROM @tabla_id;

        IF @tipo_nuevo IS NULL OR LTRIM(RTRIM(@tipo_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo del tipo de planilla.', 16, 1);
            RETURN;
        END;

        INSERT INTO PR_PayRollType (
            PayRollType,
            ShortName,
            PeriodType,
            Description,
            Title,
            PayrolltypeCurrency,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate,
            FlagAdditionalTime,
            flagmedicalrestpay,
            cumulativepay,
            DiasVacaciones
        )
        VALUES (
            @tipo_nuevo,
            @shortname,
            @periodtype,
            @description,
            @description,
            'LO',
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE(),
            'A',
            'S',
            'N',
            @diasvacaciones
        );

        SELECT
            @tipo_nuevo AS payrolltype,
            'Tipo de planilla registrado correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_PayRollType (NOLOCK)
        WHERE Company = @company
          AND PayRollType = @payrolltype
    )
    BEGIN
        RAISERROR('No se encontró el tipo de planilla a actualizar.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_PayRollType (NOLOCK)
        WHERE Company = @company
          AND LTRIM(RTRIM(ISNULL(ShortName, ''))) = @shortname
          AND PayRollType <> @payrolltype
    )
    BEGIN
        RAISERROR('Ya existe otro tipo de planilla con el mismo nombre corto para la compañía.', 16, 1);
        RETURN;
    END;

    UPDATE PR_PayRollType
    SET ShortName = @shortname,
        Description = @description,
        Title = @description,
        DiasVacaciones = @diasvacaciones,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND PayRollType = @payrolltype;

    SELECT
        @payrolltype AS payrolltype,
        'Tipo de planilla actualizado correctamente.' AS mensaje;
END
GO
