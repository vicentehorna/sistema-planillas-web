/*
    Alta / edición de PR_AFP — maestro web AFPs.

    @modo: I = nuevo (genera AFP con sp_pr_genera_correlativo_web / PR_AFP),
           U = actualizar registro existente.

    Tras grabar en la compañía origen, replica el alta/cambio en las demás
    empresas activas (match por Abreviatura AFPCode; si no hay, por Description).
    Si no existe en destino → inserta; si existe → actualiza.

    Usado por: POST /api/afps/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardaraf_web]
    @modo                 CHAR(1),
    @company              VARCHAR(4),
    @afp                  VARCHAR(20) = NULL,
    @description          VARCHAR(20),
    @afpcode              VARCHAR(20) = NULL,
    @afpcodenet           VARCHAR(20) = NULL,
    @pensionpercentage    VARCHAR(30) = NULL,
    @topafp               VARCHAR(30) = NULL,
    @fixedamount          VARCHAR(30) = NULL,
    @variablepercentage   VARCHAR(30) = NULL,
    @insuredpercentage    VARCHAR(30) = NULL,
    @pdt                  VARCHAR(20) = NULL,
    @xlastuser            VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @afp_nuevo       VARCHAR(20);
    DECLARE @afp_dest        VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));
    DECLARE @max_exist       NUMERIC(18, 0);
    DECLARE @val_pension     NUMERIC(18, 4) = NULL;
    DECLARE @val_top         NUMERIC(18, 4) = NULL;
    DECLARE @val_fixed       NUMERIC(18, 4) = NULL;
    DECLARE @val_variable    NUMERIC(18, 4) = NULL;
    DECLARE @val_insured     NUMERIC(18, 4) = NULL;
    DECLARE @cia_dest        VARCHAR(4);
    DECLARE @replicadas      INT = 0;
    DECLARE @actualizadas    INT = 0;
    DECLARE @match_code      VARCHAR(20) = NULL;
    DECLARE @match_desc      VARCHAR(20) = NULL;
    DECLARE @desc_orig       VARCHAR(20) = NULL;
    DECLARE @code_orig       VARCHAR(20) = NULL;

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @afp = NULLIF(LTRIM(RTRIM(ISNULL(@afp, ''))), '');
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @afpcode = NULLIF(LTRIM(RTRIM(ISNULL(@afpcode, ''))), '');
    SET @afpcodenet = NULLIF(LTRIM(RTRIM(ISNULL(@afpcodenet, ''))), '');
    SET @pdt = NULLIF(LTRIM(RTRIM(ISNULL(@pdt, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @pensionpercentage = NULLIF(LTRIM(RTRIM(ISNULL(@pensionpercentage, ''))), '');
    SET @topafp = NULLIF(LTRIM(RTRIM(ISNULL(@topafp, ''))), '');
    SET @fixedamount = NULLIF(LTRIM(RTRIM(ISNULL(@fixedamount, ''))), '');
    SET @variablepercentage = NULLIF(LTRIM(RTRIM(ISNULL(@variablepercentage, ''))), '');
    SET @insuredpercentage = NULLIF(LTRIM(RTRIM(ISNULL(@insuredpercentage, ''))), '');

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

    IF @description = ''
    BEGIN
        RAISERROR('Indique el nombre de la AFP.', 16, 1);
        RETURN;
    END;

    IF LEN(@description) > 20
    BEGIN
        RAISERROR('El nombre de la AFP no puede superar 20 caracteres.', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @afp IS NULL
    BEGIN
        RAISERROR('Indique el código de AFP a actualizar.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        IF @pensionpercentage IS NOT NULL
            SET @val_pension = CONVERT(NUMERIC(18, 4), REPLACE(@pensionpercentage, ',', ''));
        IF @topafp IS NOT NULL
            SET @val_top = CONVERT(NUMERIC(18, 4), REPLACE(@topafp, ',', ''));
        IF @fixedamount IS NOT NULL
            SET @val_fixed = CONVERT(NUMERIC(18, 4), REPLACE(@fixedamount, ',', ''));
        IF @variablepercentage IS NOT NULL
            SET @val_variable = CONVERT(NUMERIC(18, 4), REPLACE(@variablepercentage, ',', ''));
        IF @insuredpercentage IS NOT NULL
            SET @val_insured = CONVERT(NUMERIC(18, 4), REPLACE(@insuredpercentage, ',', ''));
    END TRY
    BEGIN CATCH
        RAISERROR('Revise los valores numéricos de porcentajes / tope.', 16, 1);
        RETURN;
    END CATCH;

    /* ---------- helpers locales: alinear correlativo en una compañía ---------- */
    /* Se invoca inline en cada destino. */

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM PR_AFP (NOLOCK)
            WHERE Company = @company
              AND LTRIM(RTRIM(ISNULL(Description, ''))) = @description
        )
        BEGIN
            RAISERROR('Ya existe una AFP con el mismo nombre para la compañía.', 16, 1);
            RETURN;
        END;

        SELECT @max_exist = ISNULL(MAX(TRY_CONVERT(NUMERIC(18, 0), RIGHT(RTRIM(AFP), 12))), 0)
        FROM PR_AFP (NOLOCK)
        WHERE Company = @company;

        IF NOT EXISTS (
            SELECT 1
            FROM SY_ObjectSecuence (NOLOCK)
            WHERE Company = @company
              AND Object = 'PR_AFP'
              AND ReplicationUnit = @replicationunit
        )
        BEGIN
            INSERT INTO SY_ObjectSecuence (
                Company, Object, ReplicationUnit, Secuence, XLastUser, XLastDate
            )
            VALUES (
                @company, 'PR_AFP', @replicationunit, @max_exist, @xlastuser, GETDATE()
            );
        END
        ELSE
        BEGIN
            UPDATE SY_ObjectSecuence
            SET Secuence = CASE WHEN Secuence < @max_exist THEN @max_exist ELSE Secuence END,
                XLastUser = ISNULL(@xlastuser, XLastUser),
                XLastDate = GETDATE()
            WHERE Company = @company
              AND Object = 'PR_AFP'
              AND ReplicationUnit = @replicationunit;
        END;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'PR_AFP',
            @xlastuser = @xlastuser;

        SELECT @afp_nuevo = id_generado FROM @tabla_id;

        IF @afp_nuevo IS NULL OR LTRIM(RTRIM(@afp_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo de la AFP.', 16, 1);
            RETURN;
        END;

        IF EXISTS (SELECT 1 FROM PR_AFP (NOLOCK) WHERE AFP = @afp_nuevo)
        BEGIN
            RAISERROR('El correlativo generado ya existe. Reintente el alta.', 16, 1);
            RETURN;
        END;

        INSERT INTO PR_AFP (
            AFP, Description, Vendor, PensionPercentage, TopAFP, TopAFPCurrency,
            FixedAmount, VariablePercentage, InsuredPercentage,
            Company, ReplicationUnit, XLastUser, XLastDate,
            AFPCode, pdt, afpcodenet
        )
        VALUES (
            @afp_nuevo, @description, NULL, @val_pension, @val_top, 'LO',
            @val_fixed, @val_variable, @val_insured,
            @company, @replicationunit, @xlastuser, GETDATE(),
            @afpcode, @pdt, @afpcodenet
        );

        SET @afp = @afp_nuevo;
        SET @match_code = @afpcode;
        SET @match_desc = @description;
    END
    ELSE
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM PR_AFP (NOLOCK)
            WHERE Company = @company
              AND AFP = @afp
        )
        BEGIN
            RAISERROR('No se encontró la AFP a actualizar.', 16, 1);
            RETURN;
        END;

        SELECT
            @desc_orig = LTRIM(RTRIM(ISNULL(Description, ''))),
            @code_orig = NULLIF(LTRIM(RTRIM(ISNULL(AFPCode, ''))), '')
        FROM PR_AFP (NOLOCK)
        WHERE Company = @company
          AND AFP = @afp;

        IF EXISTS (
            SELECT 1
            FROM PR_AFP (NOLOCK)
            WHERE Company = @company
              AND LTRIM(RTRIM(ISNULL(Description, ''))) = @description
              AND AFP <> @afp
        )
        BEGIN
            RAISERROR('Ya existe otra AFP con el mismo nombre para la compañía.', 16, 1);
            RETURN;
        END;

        UPDATE PR_AFP
        SET Description = @description,
            PensionPercentage = @val_pension,
            TopAFP = @val_top,
            FixedAmount = @val_fixed,
            VariablePercentage = @val_variable,
            InsuredPercentage = @val_insured,
            AFPCode = @afpcode,
            pdt = @pdt,
            afpcodenet = @afpcodenet,
            XLastUser = @xlastuser,
            XLastDate = GETDATE()
        WHERE Company = @company
          AND AFP = @afp;

        /* Match en destinos: abreviatura original (o nueva) / descripción original. */
        SET @match_code = COALESCE(@code_orig, @afpcode);
        SET @match_desc = ISNULL(NULLIF(@desc_orig, ''), @description);
    END;

    /* ---------- Réplica a demás empresas activas ---------- */
    DECLARE empresas CURSOR LOCAL FAST_FORWARD FOR
        SELECT LTRIM(RTRIM(Company))
        FROM SY_Company (NOLOCK)
        WHERE LTRIM(RTRIM(Company)) <> @company
          AND ISNULL(status, 'A') = 'A';

    OPEN empresas;
    FETCH NEXT FROM empresas INTO @cia_dest;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @afp_dest = NULL;

        SELECT TOP 1 @afp_dest = a.AFP
        FROM PR_AFP a (NOLOCK)
        WHERE a.Company = @cia_dest
          AND (
                (
                    @match_code IS NOT NULL
                    AND LTRIM(RTRIM(ISNULL(a.AFPCode, ''))) = @match_code
                )
             OR LTRIM(RTRIM(ISNULL(a.Description, ''))) = @match_desc
             OR LTRIM(RTRIM(ISNULL(a.Description, ''))) = @description
          )
        ORDER BY
            CASE
                WHEN @match_code IS NOT NULL
                     AND LTRIM(RTRIM(ISNULL(a.AFPCode, ''))) = @match_code THEN 0
                WHEN LTRIM(RTRIM(ISNULL(a.Description, ''))) = @match_desc THEN 1
                ELSE 2
            END,
            a.AFP;

        IF @afp_dest IS NOT NULL
        BEGIN
            UPDATE PR_AFP
            SET Description = @description,
                PensionPercentage = @val_pension,
                TopAFP = @val_top,
                FixedAmount = @val_fixed,
                VariablePercentage = @val_variable,
                InsuredPercentage = @val_insured,
                AFPCode = @afpcode,
                pdt = @pdt,
                afpcodenet = @afpcodenet,
                XLastUser = @xlastuser,
                XLastDate = GETDATE()
            WHERE Company = @cia_dest
              AND AFP = @afp_dest;

            SET @actualizadas = @actualizadas + 1;
        END
        ELSE IF NOT EXISTS (
            SELECT 1
            FROM PR_AFP (NOLOCK)
            WHERE Company = @cia_dest
              AND LTRIM(RTRIM(ISNULL(Description, ''))) = @description
        )
        BEGIN
            /* Alta en destino: correlativo + insert */
            SELECT @max_exist = ISNULL(MAX(TRY_CONVERT(NUMERIC(18, 0), RIGHT(RTRIM(AFP), 12))), 0)
            FROM PR_AFP (NOLOCK)
            WHERE Company = @cia_dest;

            IF NOT EXISTS (
                SELECT 1
                FROM SY_ObjectSecuence (NOLOCK)
                WHERE Company = @cia_dest
                  AND Object = 'PR_AFP'
                  AND ReplicationUnit = @replicationunit
            )
            BEGIN
                INSERT INTO SY_ObjectSecuence (
                    Company, Object, ReplicationUnit, Secuence, XLastUser, XLastDate
                )
                VALUES (
                    @cia_dest, 'PR_AFP', @replicationunit, @max_exist, @xlastuser, GETDATE()
                );
            END
            ELSE
            BEGIN
                UPDATE SY_ObjectSecuence
                SET Secuence = CASE WHEN Secuence < @max_exist THEN @max_exist ELSE Secuence END,
                    XLastUser = ISNULL(@xlastuser, XLastUser),
                    XLastDate = GETDATE()
                WHERE Company = @cia_dest
                  AND Object = 'PR_AFP'
                  AND ReplicationUnit = @replicationunit;
            END;

            DELETE FROM @tabla_id;

            BEGIN TRY
                INSERT INTO @tabla_id (id_generado)
                EXEC dbo.sp_pr_genera_correlativo_web
                    @cia = @cia_dest,
                    @object = 'PR_AFP',
                    @xlastuser = @xlastuser;

                SELECT @afp_dest = id_generado FROM @tabla_id;

                IF @afp_dest IS NOT NULL
                   AND LTRIM(RTRIM(@afp_dest)) <> ''
                   AND NOT EXISTS (SELECT 1 FROM PR_AFP (NOLOCK) WHERE AFP = @afp_dest)
                BEGIN
                    INSERT INTO PR_AFP (
                        AFP, Description, Vendor, PensionPercentage, TopAFP, TopAFPCurrency,
                        FixedAmount, VariablePercentage, InsuredPercentage,
                        Company, ReplicationUnit, XLastUser, XLastDate,
                        AFPCode, pdt, afpcodenet
                    )
                    VALUES (
                        @afp_dest, @description, NULL, @val_pension, @val_top, 'LO',
                        @val_fixed, @val_variable, @val_insured,
                        @cia_dest, @replicationunit, @xlastuser, GETDATE(),
                        @afpcode, @pdt, @afpcodenet
                    );
                    SET @replicadas = @replicadas + 1;
                END;
            END TRY
            BEGIN CATCH
                /* No aborta el guardado origen si falla una empresa destino. */
                SET @afp_dest = NULL;
            END CATCH;
        END;

        FETCH NEXT FROM empresas INTO @cia_dest;
    END;

    CLOSE empresas;
    DEALLOCATE empresas;

    DECLARE @msg VARCHAR(200);
    IF @modo = 'I'
        SET @msg = 'AFP registrada correctamente.';
    ELSE
        SET @msg = 'AFP actualizada correctamente.';

    IF @replicadas > 0 OR @actualizadas > 0
    BEGIN
        SET @msg = @msg + ' Réplica:';
        IF @replicadas > 0
            SET @msg = @msg + ' ' + CAST(@replicadas AS VARCHAR(10))
                + CASE WHEN @replicadas = 1 THEN ' alta' ELSE ' altas' END;
        IF @actualizadas > 0
            SET @msg = @msg + ' ' + CAST(@actualizadas AS VARCHAR(10))
                + CASE WHEN @actualizadas = 1 THEN ' actualización' ELSE ' actualizaciones' END;
        SET @msg = @msg + ' en otras empresas.';
    END;

    SELECT
        @afp AS afp,
        @msg AS mensaje;
END
GO
