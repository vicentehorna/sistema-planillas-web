/*
    Alta / edición de PR_Parameter — maestro web Parámetros.

    @modo: I = nuevo (genera Parameter con sp_pr_genera_correlativo_web / PR_PARAMETER),
           U = actualizar (ShortName no cambia).

    ParameterTypeValue: N = Numérico, T = Texto.
    En alta, ParameterType se guarda como 'U' (usuario). FlagEnable = 'Y'.

    Usado por: POST /api/parametros/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarparametro_web]
    @modo                  CHAR(1),
    @company               VARCHAR(4),
    @parameter             VARCHAR(20) = NULL,
    @shortname             VARCHAR(20),
    @description           VARCHAR(100),
    @parametertypevalue    CHAR(1),
    @parametertextvalue    VARCHAR(100) = NULL,
    @parameternumbervalue  NUMERIC(19, 4) = NULL,
    @xlastuser             VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @parameter_nuevo VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));
    DECLARE @tipo            CHAR(1);

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @parameter = NULLIF(LTRIM(RTRIM(ISNULL(@parameter, ''))), '');
    SET @shortname = UPPER(LTRIM(RTRIM(ISNULL(@shortname, ''))));
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @tipo = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@parametertypevalue, ''))), 1));
    SET @parametertextvalue = NULLIF(LTRIM(RTRIM(ISNULL(@parametertextvalue, ''))), '');
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

    IF @shortname = ''
    BEGIN
        RAISERROR('Indique el nombre del parámetro (ShortName).', 16, 1);
        RETURN;
    END;

    IF LEN(@shortname) > 20
    BEGIN
        RAISERROR('El parámetro (ShortName) no puede superar 20 caracteres.', 16, 1);
        RETURN;
    END;

    IF @description = ''
    BEGIN
        RAISERROR('Indique la descripción del parámetro.', 16, 1);
        RETURN;
    END;

    IF @tipo NOT IN ('N', 'T')
    BEGIN
        RAISERROR('Tipo de parámetro inválido. Use N (Numérico) o T (Texto).', 16, 1);
        RETURN;
    END;

    IF @tipo = 'N'
    BEGIN
        SET @parametertextvalue = NULL;
        IF @parameternumbervalue IS NULL
            SET @parameternumbervalue = 0;
    END
    ELSE
    BEGIN
        SET @parameternumbervalue = NULL;
        IF @parametertextvalue IS NULL
            SET @parametertextvalue = '';
    END;

    IF @modo = 'U' AND @parameter IS NULL
    BEGIN
        RAISERROR('Indique el parámetro a actualizar.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM PR_Parameter (NOLOCK)
            WHERE Company = @company
              AND UPPER(LTRIM(RTRIM(ISNULL(ShortName, '')))) = @shortname
        )
        BEGIN
            RAISERROR('Ya existe un parámetro con el mismo ShortName en la compañía.', 16, 1);
            RETURN;
        END;

        DECLARE @tries INT = 0;
        SET @parameter_nuevo = NULL;

        WHILE @tries < 100 AND (@parameter_nuevo IS NULL OR EXISTS (
            SELECT 1 FROM PR_Parameter (NOLOCK) WHERE Parameter = @parameter_nuevo
        ))
        BEGIN
            DELETE FROM @tabla_id;

            INSERT INTO @tabla_id (id_generado)
            EXEC dbo.sp_pr_genera_correlativo_web
                @cia = @company,
                @object = 'PR_PARAMETER',
                @xlastuser = @xlastuser;

            SELECT @parameter_nuevo = NULLIF(LTRIM(RTRIM(id_generado)), '') FROM @tabla_id;
            SET @tries = @tries + 1;
        END;

        IF @parameter_nuevo IS NULL OR LTRIM(RTRIM(@parameter_nuevo)) = ''
           OR EXISTS (SELECT 1 FROM PR_Parameter (NOLOCK) WHERE Parameter = @parameter_nuevo)
        BEGIN
            RAISERROR('No se pudo generar un correlativo libre para el parámetro.', 16, 1);
            RETURN;
        END;

        INSERT INTO PR_Parameter (
            Parameter,
            ParameterType,
            ShortName,
            Description,
            ParameterTypeValue,
            ParameterTextValue,
            ParameterNumberValue,
            FlagEnable,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate
        )
        VALUES (
            @parameter_nuevo,
            'U',
            @shortname,
            @description,
            @tipo,
            @parametertextvalue,
            @parameternumbervalue,
            'Y',
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE()
        );

        SELECT
            @parameter_nuevo AS parameter,
            @shortname AS shortname,
            'I' AS modo,
            'Parámetro registrado correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Parameter (NOLOCK)
        WHERE Company = @company
          AND Parameter = @parameter
    )
    BEGIN
        RAISERROR('No se encontró el parámetro a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE PR_Parameter
    SET Description = @description,
        ParameterTypeValue = @tipo,
        ParameterTextValue = @parametertextvalue,
        ParameterNumberValue = @parameternumbervalue,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND Parameter = @parameter;

    SELECT
        @parameter AS parameter,
        @shortname AS shortname,
        'U' AS modo,
        'Parámetro actualizado correctamente.' AS mensaje;
END
GO
