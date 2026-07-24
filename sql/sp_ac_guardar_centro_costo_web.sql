/*
    Maestro Centros de Costo — alta / edición de AC_CostCenter.
    El ID CostCenter se genera desde SY_ObjectSecuence, objeto ACCOSTCENTER.

    Defaults en alta:
      Name              = Description (truncado a 50)
      CCCode            = Abbrev
      CCLevel           = 1
      FlagDistribution  = 'N'
      Status            = 'A'
      ReplicationUnit   = 'LIMA'
      XLastUser/XLastDate = auditoría

    Usado por: POST /api/centros-costo/guardar

    En alta (modo I): tras grabar en la compañía origen, replica el centro
    en las demás empresas activas donde aún no exista el mismo Abbrev.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ac_guardar_centro_costo_web]
    @modo         CHAR(1),
    @company      VARCHAR(4),
    @costcenter   VARCHAR(20) = NULL,
    @abbrev       VARCHAR(20),
    @description  VARCHAR(255),
    @xlastuser    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @costcenter_nuevo VARCHAR(20);
    DECLARE @name VARCHAR(50);
    DECLARE @tabla_id TABLE (id_generado VARCHAR(20));
    DECLARE @cia_dest VARCHAR(4);
    DECLARE @costcenter_dest VARCHAR(20);
    DECLARE @max_seq NUMERIC(18, 0);
    DECLARE @replicadas INT = 0;

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @costcenter = NULLIF(LTRIM(RTRIM(ISNULL(@costcenter, ''))), '');
    SET @abbrev = LTRIM(RTRIM(ISNULL(@abbrev, '')));
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @name = LEFT(@description, 50);

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido.', 16, 1);
        RETURN;
    END;

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @abbrev = '' OR @description = ''
    BEGIN
        RAISERROR('Indique la abreviatura y la descripción del centro de costo.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM AC_CostCenter (NOLOCK)
        WHERE Company = @company
          AND LTRIM(RTRIM(ISNULL(Abbrev, ''))) = @abbrev
          AND (@modo = 'I' OR CostCenter <> @costcenter)
    )
    BEGIN
        RAISERROR('Ya existe un centro de costo con la misma abreviatura.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'ACCOSTCENTER',
            @xlastuser = @xlastuser;

        SELECT @costcenter_nuevo = id_generado FROM @tabla_id;

        IF NULLIF(LTRIM(RTRIM(ISNULL(@costcenter_nuevo, ''))), '') IS NULL
        BEGIN
            RAISERROR('No se pudo generar el correlativo del centro de costo.', 16, 1);
            RETURN;
        END;

        INSERT INTO AC_CostCenter (
            CostCenter, Company, Name, Description, Abbrev,
            Status, CCCode, CCLevel, FlagDistribution,
            ReplicationUnit, XLastUser, XLastDate
        )
        VALUES (
            @costcenter_nuevo, @company, @name, @description, @abbrev,
            'A', @abbrev, 1, 'N',
            'LIMA', @xlastuser, GETDATE()
        );

        /* Replica a otras empresas activas si no tienen la misma abreviatura. */
        DECLARE empresas CURSOR LOCAL FAST_FORWARD FOR
            SELECT LTRIM(RTRIM(Company))
            FROM SY_Company (NOLOCK)
            WHERE LTRIM(RTRIM(Company)) <> @company
              AND ISNULL(status, 'A') = 'A';

        OPEN empresas;
        FETCH NEXT FROM empresas INTO @cia_dest;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM AC_CostCenter (NOLOCK)
                WHERE Company = @cia_dest
                  AND LTRIM(RTRIM(ISNULL(Abbrev, ''))) = @abbrev
            )
            AND EXISTS (
                SELECT 1
                FROM SY_ObjectSecuence (NOLOCK)
                WHERE Company = @cia_dest
                  AND Object = 'ACCOSTCENTER'
                  AND ReplicationUnit = 'LIMA'
            )
            BEGIN
                SELECT @max_seq = MAX(
                    CASE
                        WHEN ISNUMERIC(RIGHT(LTRIM(RTRIM(CostCenter)), 12)) = 1
                        THEN CAST(RIGHT(LTRIM(RTRIM(CostCenter)), 12) AS BIGINT)
                        ELSE NULL
                    END
                )
                FROM AC_CostCenter (NOLOCK)
                WHERE Company = @cia_dest;

                IF @max_seq IS NOT NULL
                BEGIN
                    UPDATE SY_ObjectSecuence
                    SET Secuence = @max_seq
                    WHERE Company = @cia_dest
                      AND Object = 'ACCOSTCENTER'
                      AND ReplicationUnit = 'LIMA'
                      AND Secuence < @max_seq;
                END;

                DELETE FROM @tabla_id;

                INSERT INTO @tabla_id (id_generado)
                EXEC dbo.sp_pr_genera_correlativo_web
                    @cia = @cia_dest,
                    @object = 'ACCOSTCENTER',
                    @xlastuser = @xlastuser;

                SELECT @costcenter_dest = id_generado FROM @tabla_id;

                IF NULLIF(LTRIM(RTRIM(ISNULL(@costcenter_dest, ''))), '') IS NOT NULL
                   AND NOT EXISTS (
                        SELECT 1 FROM AC_CostCenter (NOLOCK) WHERE CostCenter = @costcenter_dest
                   )
                BEGIN
                    INSERT INTO AC_CostCenter (
                        CostCenter, Company, Name, Description, Abbrev,
                        Status, CCCode, CCLevel, FlagDistribution,
                        ReplicationUnit, XLastUser, XLastDate
                    )
                    VALUES (
                        @costcenter_dest, @cia_dest, @name, @description, @abbrev,
                        'A', @abbrev, 1, 'N',
                        'LIMA', @xlastuser, GETDATE()
                    );
                    SET @replicadas = @replicadas + 1;
                END;
            END;

            FETCH NEXT FROM empresas INTO @cia_dest;
        END;

        CLOSE empresas;
        DEALLOCATE empresas;

        SELECT
            @costcenter_nuevo AS costcenter,
            CASE
                WHEN @replicadas > 0 THEN
                    'Centro de costo registrado correctamente. Replicado en '
                    + CAST(@replicadas AS VARCHAR(10))
                    + CASE WHEN @replicadas = 1 THEN ' empresa.' ELSE ' empresas.' END
                ELSE
                    'Centro de costo registrado correctamente.'
            END AS mensaje;
        RETURN;
    END;

    IF @costcenter IS NULL OR NOT EXISTS (
        SELECT 1
        FROM AC_CostCenter (NOLOCK)
        WHERE Company = @company
          AND CostCenter = @costcenter
    )
    BEGIN
        RAISERROR('No se encontró el centro de costo a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE AC_CostCenter
    SET Abbrev = @abbrev,
        Description = @description,
        Name = @name,
        CCCode = @abbrev,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND CostCenter = @costcenter;

    SELECT
        @costcenter AS costcenter,
        'Centro de costo actualizado correctamente.' AS mensaje;
END
GO
