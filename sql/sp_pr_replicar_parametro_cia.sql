/*
    Replica un parámetro por ShortName desde compañía origen hacia destino
    (misma BD). Genera Parameter con SP_SY / PR_PARAMETER.

    Uso típico BGT -> SB01:
        EXEC dbo.sp_pr_replicar_parametro_cia
            @cia = 'SB01',
            @shortname = 'FACTOR_UIT',
            @cia_origen = 'BGT';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_replicar_parametro_cia]
    @cia         VARCHAR(4),
    @shortname   VARCHAR(20),
    @cia_origen  VARCHAR(4) = 'BGT',
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id              VARCHAR(20);
    DECLARE @msg             VARCHAR(500);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));
    DECLARE @replicationunit VARCHAR(4) = 'LIMA';

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @shortname = UPPER(LTRIM(RTRIM(ISNULL(@shortname, ''))));
    SET @cia_origen = LTRIM(RTRIM(ISNULL(@cia_origen, 'BGT')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = '' OR @shortname = ''
    BEGIN
        RAISERROR('Indique compañía destino y ShortName.', 16, 1);
        RETURN;
    END;

    IF @cia = @cia_origen
    BEGIN
        RAISERROR('La compañía destino debe ser distinta de la compañía origen.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Parameter
        WHERE Company = @cia
          AND UPPER(LTRIM(RTRIM(ISNULL(ShortName, '')))) = @shortname
    )
    BEGIN
        SELECT
            p.Parameter AS parameter,
            p.ShortName AS shortname,
            'El parámetro ya existe en la compañía destino.' AS mensaje
        FROM PR_Parameter p
        WHERE p.Company = @cia
          AND UPPER(LTRIM(RTRIM(ISNULL(p.ShortName, '')))) = @shortname;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Parameter
        WHERE Company = @cia_origen
          AND UPPER(LTRIM(RTRIM(ISNULL(ShortName, '')))) = @shortname
    )
    BEGIN
        SET @msg = 'No existe parámetro origen en ' + @cia_origen
                 + ' con ShortName ' + @shortname + '.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM SY_ObjectSecuence (NOLOCK)
        WHERE Company = @cia
          AND Object = 'PR_PARAMETER'
          AND ReplicationUnit = @replicationunit
    )
    BEGIN
        INSERT INTO SY_ObjectSecuence (
            Object, Secuence, Company, XLastUser, XLastDate, ReplicationUnit
        )
        VALUES (
            'PR_PARAMETER', 0, @cia,
            ISNULL(@xlastuser, 'WEB'), GETDATE(), @replicationunit
        );
    END;

    DECLARE @tries INT = 0;
    SET @id = NULL;

    WHILE @tries < 100 AND (@id IS NULL OR EXISTS (
        SELECT 1 FROM PR_Parameter (NOLOCK) WHERE Parameter = @id
    ))
    BEGIN
        DELETE FROM @tabla_id;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @cia,
            @object = 'PR_PARAMETER',
            @xlastuser = @xlastuser;

        SELECT @id = NULLIF(LTRIM(RTRIM(id_generado)), '') FROM @tabla_id;
        SET @tries = @tries + 1;
    END;

    IF @id IS NULL OR LTRIM(RTRIM(@id)) = ''
       OR EXISTS (SELECT 1 FROM PR_Parameter (NOLOCK) WHERE Parameter = @id)
    BEGIN
        RAISERROR('No se pudo generar un correlativo libre del parámetro en destino.', 16, 1);
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
    SELECT
        @id,
        'U',
        UPPER(LTRIM(RTRIM(ISNULL(T.ShortName, '')))),
        T.Description,
        UPPER(LEFT(LTRIM(RTRIM(ISNULL(T.ParameterTypeValue, 'N'))), 1)),
        T.ParameterTextValue,
        T.ParameterNumberValue,
        ISNULL(NULLIF(LTRIM(RTRIM(T.FlagEnable)), ''), 'Y'),
        @cia,
        ISNULL(NULLIF(LTRIM(RTRIM(T.ReplicationUnit)), ''), @replicationunit),
        ISNULL(@xlastuser, T.XLastUser),
        GETDATE()
    FROM PR_Parameter T
    WHERE T.Company = @cia_origen
      AND UPPER(LTRIM(RTRIM(ISNULL(T.ShortName, '')))) = @shortname;

    SELECT
        @id AS parameter,
        @shortname AS shortname,
        'Parámetro replicado correctamente.' AS mensaje;
END
GO
