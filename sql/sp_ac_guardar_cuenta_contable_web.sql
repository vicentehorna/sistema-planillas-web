/*
    Maestro Cuentas Contables — alta / edición de AC_Account.
    El ID Account se genera desde SY_ObjectSecuence, objeto ACACCOUNT.
    Usado por: POST /api/asientos/cuentas-contables/guardar

    En alta (modo I): tras grabar en la compañía origen, replica la cuenta
    en las demás empresas activas donde aún no exista el mismo Code.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ac_guardar_cuenta_contable_web]
    @modo      CHAR(1),
    @company   VARCHAR(4),
    @account   VARCHAR(20) = NULL,
    @code      VARCHAR(255),
    @name      VARCHAR(255),
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @account_nuevo VARCHAR(20);
    DECLARE @tabla_id TABLE (id_generado VARCHAR(20));
    DECLARE @cia_dest VARCHAR(4);
    DECLARE @account_dest VARCHAR(20);
    DECLARE @max_seq NUMERIC(18, 0);
    DECLARE @replicadas INT = 0;

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @account = NULLIF(LTRIM(RTRIM(ISNULL(@account, ''))), '');
    SET @code = LTRIM(RTRIM(ISNULL(@code, '')));
    SET @name = LTRIM(RTRIM(ISNULL(@name, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

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

    IF @code = '' OR @name = ''
    BEGIN
        RAISERROR('Indique el código y nombre de la cuenta contable.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM AC_Account (NOLOCK)
        WHERE Company = @company
          AND LTRIM(RTRIM(ISNULL(Code, ''))) = @code
          AND (@modo = 'I' OR Account <> @account)
    )
    BEGIN
        RAISERROR('Ya existe una cuenta contable con el mismo código.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'ACACCOUNT',
            @xlastuser = @xlastuser;

        SELECT @account_nuevo = id_generado FROM @tabla_id;

        IF NULLIF(LTRIM(RTRIM(ISNULL(@account_nuevo, ''))), '') IS NULL
        BEGIN
            RAISERROR('No se pudo generar el correlativo de la cuenta contable.', 16, 1);
            RETURN;
        END;

        INSERT INTO AC_Account (
            Account, Company, Code, Name, Description,
            ACCurrency, Status, XLastUser, XLastDate
        )
        VALUES (
            @account_nuevo, @company, @code, @name, @name,
            'LO', 'A', @xlastuser, GETDATE()
        );

        /* Replica a otras empresas activas si no tienen el mismo código. */
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
                FROM AC_Account (NOLOCK)
                WHERE Company = @cia_dest
                  AND LTRIM(RTRIM(ISNULL(Code, ''))) = @code
            )
            AND EXISTS (
                SELECT 1
                FROM SY_ObjectSecuence (NOLOCK)
                WHERE Company = @cia_dest
                  AND Object = 'ACACCOUNT'
                  AND ReplicationUnit = 'LIMA'
            )
            BEGIN
                /* Asegura correlativo >= máximo ID existente en la compañía destino. */
                SELECT @max_seq = MAX(
                    CASE
                        WHEN ISNUMERIC(RIGHT(LTRIM(RTRIM(Account)), 12)) = 1
                        THEN CAST(RIGHT(LTRIM(RTRIM(Account)), 12) AS BIGINT)
                        ELSE NULL
                    END
                )
                FROM AC_Account (NOLOCK)
                WHERE Company = @cia_dest;

                IF @max_seq IS NOT NULL
                BEGIN
                    UPDATE SY_ObjectSecuence
                    SET Secuence = @max_seq
                    WHERE Company = @cia_dest
                      AND Object = 'ACACCOUNT'
                      AND ReplicationUnit = 'LIMA'
                      AND Secuence < @max_seq;
                END;

                DELETE FROM @tabla_id;

                INSERT INTO @tabla_id (id_generado)
                EXEC dbo.sp_pr_genera_correlativo_web
                    @cia = @cia_dest,
                    @object = 'ACACCOUNT',
                    @xlastuser = @xlastuser;

                SELECT @account_dest = id_generado FROM @tabla_id;

                IF NULLIF(LTRIM(RTRIM(ISNULL(@account_dest, ''))), '') IS NOT NULL
                   AND NOT EXISTS (
                        SELECT 1 FROM AC_Account (NOLOCK) WHERE Account = @account_dest
                   )
                BEGIN
                    INSERT INTO AC_Account (
                        Account, Company, Code, Name, Description,
                        ACCurrency, Status, XLastUser, XLastDate
                    )
                    VALUES (
                        @account_dest, @cia_dest, @code, @name, @name,
                        'LO', 'A', @xlastuser, GETDATE()
                    );
                    SET @replicadas = @replicadas + 1;
                END;
            END;

            FETCH NEXT FROM empresas INTO @cia_dest;
        END;

        CLOSE empresas;
        DEALLOCATE empresas;

        SELECT
            @account_nuevo AS account,
            CASE
                WHEN @replicadas > 0 THEN
                    'Cuenta contable registrada correctamente. Replicada en '
                    + CAST(@replicadas AS VARCHAR(10))
                    + CASE WHEN @replicadas = 1 THEN ' empresa.' ELSE ' empresas.' END
                ELSE
                    'Cuenta contable registrada correctamente.'
            END AS mensaje;
        RETURN;
    END;

    IF @account IS NULL OR NOT EXISTS (
        SELECT 1
        FROM AC_Account (NOLOCK)
        WHERE Company = @company
          AND Account = @account
    )
    BEGIN
        RAISERROR('No se encontró la cuenta contable a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE AC_Account
    SET Code = @code,
        Name = @name,
        Description = @name,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND Account = @account;

    SELECT
        @account AS account,
        'Cuenta contable actualizada correctamente.' AS mensaje;
END
GO
