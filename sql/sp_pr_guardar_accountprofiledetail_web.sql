/*
    Alta / edición de PR_AccountProfileDetail (configuración conceptos ↔ cuentas).

    @modo: I = nuevo (genera Detail con correlativo PR_ACCPROFILEDET),
           U = actualizar por Detail + AccountProfile.

    Moneda fija: LO (Soles).
    Usado por: POST /api/asientos/configurar-conceptos/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardar_accountprofiledetail_web]
    @modo               CHAR(1),
    @company            VARCHAR(4),
    @detail             VARCHAR(20) = NULL,
    @accountprofile     VARCHAR(20),
    @concept            VARCHAR(20),
    @processtype        VARCHAR(20),
    @debitaccount       VARCHAR(20) = NULL,
    @debitaccountcode   VARCHAR(20) = NULL,
    @creditaccount      VARCHAR(20) = NULL,
    @creditaccountcode  VARCHAR(20) = NULL,
    @flagsumtype        CHAR(1) = 'T',
    @xlastuser          VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @detail_nuevo    VARCHAR(20);
    DECLARE @currency        VARCHAR(2) = 'LO';
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @detail = NULLIF(LTRIM(RTRIM(ISNULL(@detail, ''))), '');
    SET @accountprofile = LTRIM(RTRIM(ISNULL(@accountprofile, '')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @debitaccount = NULLIF(LTRIM(RTRIM(ISNULL(@debitaccount, ''))), '');
    SET @debitaccountcode = NULLIF(LTRIM(RTRIM(ISNULL(@debitaccountcode, ''))), '');
    SET @creditaccount = NULLIF(LTRIM(RTRIM(ISNULL(@creditaccount, ''))), '');
    SET @creditaccountcode = NULLIF(LTRIM(RTRIM(ISNULL(@creditaccountcode, ''))), '');
    SET @flagsumtype = UPPER(LTRIM(RTRIM(ISNULL(@flagsumtype, 'T'))));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @company = '' OR @accountprofile = '' OR @concept = '' OR @processtype = ''
    BEGIN
        RAISERROR('Indique compañía, perfil contable, proceso y concepto.', 16, 1);
        RETURN;
    END;

    IF @flagsumtype NOT IN ('T', 'C', 'O')
    BEGIN
        RAISERROR('Detalle a nivel inválido. Use T (Trabajador), C (Centro de Costo) u O (Concepto).', 16, 1);
        RETURN;
    END;

    IF @debitaccountcode IS NULL AND @creditaccountcode IS NULL
    BEGIN
        RAISERROR('Indique al menos una cuenta de crédito o débito.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_AccountProfile (NOLOCK)
        WHERE Company = @company
          AND AccountProfile = @accountprofile
    )
    BEGIN
        RAISERROR('El perfil contable no existe para la compañía.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Concept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept
    )
    BEGIN
        RAISERROR('El concepto no existe para la compañía.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_ProcessType (NOLOCK)
        WHERE Company = @company
          AND ProcessType = @processtype
    )
    BEGIN
        RAISERROR('El proceso no existe para la compañía.', 16, 1);
        RETURN;
    END;

    /* Resolver PK de cuenta contable a partir del código si faltara. */
    IF @creditaccountcode IS NOT NULL AND @creditaccount IS NULL
        SELECT TOP 1 @creditaccount = a.Account
        FROM AC_Account a (NOLOCK)
        WHERE a.Company = @company
          AND a.Code = @creditaccountcode
          AND a.Status = 'A'
        ORDER BY a.Account;

    IF @debitaccountcode IS NOT NULL AND @debitaccount IS NULL
        SELECT TOP 1 @debitaccount = a.Account
        FROM AC_Account a (NOLOCK)
        WHERE a.Company = @company
          AND a.Code = @debitaccountcode
          AND a.Status = 'A'
        ORDER BY a.Account;

    IF @creditaccountcode IS NOT NULL AND @creditaccount IS NULL
    BEGIN
        RAISERROR('La cuenta de crédito no existe o no está activa.', 16, 1);
        RETURN;
    END;

    IF @debitaccountcode IS NOT NULL AND @debitaccount IS NULL
    BEGIN
        RAISERROR('La cuenta de débito no existe o no está activa.', 16, 1);
        RETURN;
    END;

    IF @creditaccountcode IS NULL
        SET @creditaccount = NULL;

    IF @debitaccountcode IS NULL
        SET @debitaccount = NULL;

    IF @modo = 'U' AND @detail IS NULL
    BEGIN
        RAISERROR('Indique el detalle a actualizar.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'PR_ACCPROFILEDET',
            @xlastuser = @xlastuser;

        SELECT @detail_nuevo = id_generado FROM @tabla_id;

        IF @detail_nuevo IS NULL OR LTRIM(RTRIM(@detail_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo del detalle.', 16, 1);
            RETURN;
        END;

        INSERT INTO PR_AccountProfileDetail (
            Detail,
            AccountProfile,
            Concept,
            ProcessType,
            DebitAccount,
            DebitAccountCode,
            CreditAccount,
            CreditAccountCode,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate,
            FlagSumType,
            currency
        )
        VALUES (
            @detail_nuevo,
            @accountprofile,
            @concept,
            @processtype,
            @debitaccount,
            ISNULL(@debitaccountcode, ''),
            @creditaccount,
            ISNULL(@creditaccountcode, ''),
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE(),
            @flagsumtype,
            @currency
        );

        SELECT
            @detail_nuevo AS detail,
            @accountprofile AS accountprofile,
            'Configuración registrada correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_AccountProfileDetail (NOLOCK)
        WHERE Detail = @detail
          AND AccountProfile = @accountprofile
          AND Company = @company
    )
    BEGIN
        RAISERROR('No se encontró la configuración a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE PR_AccountProfileDetail
    SET Concept = @concept,
        ProcessType = @processtype,
        DebitAccount = @debitaccount,
        DebitAccountCode = ISNULL(@debitaccountcode, ''),
        CreditAccount = @creditaccount,
        CreditAccountCode = ISNULL(@creditaccountcode, ''),
        FlagSumType = @flagsumtype,
        currency = @currency,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Detail = @detail
      AND AccountProfile = @accountprofile
      AND Company = @company;

    SELECT
        @detail AS detail,
        @accountprofile AS accountprofile,
        'Configuración actualizada correctamente.' AS mensaje;
END
GO
