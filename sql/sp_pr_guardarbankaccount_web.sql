/*
    Alta / edición de TE_BankAccount — maestro web Cuentas Bancarias.

    @modo: I = nuevo (genera BankAccount con sp_pr_genera_correlativo_web / TE_BANKACCOUNT),
           U = actualizar registro existente.

    Usado por: POST /api/cuentas-bancarias/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarbankaccount_web]
    @modo               CHAR(1),
    @company            VARCHAR(4),
    @bankaccount        VARCHAR(20) = NULL,
    @accounttype        VARCHAR(20),
    @bank               VARCHAR(20),
    @bankaccountnumber  VARCHAR(30),
    @xlastuser          VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @bankaccount_nuevo VARCHAR(20);
    DECLARE @tabla_id TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @bankaccount = NULLIF(LTRIM(RTRIM(ISNULL(@bankaccount, ''))), '');
    SET @accounttype = LTRIM(RTRIM(ISNULL(@accounttype, '')));
    SET @bank = LTRIM(RTRIM(ISNULL(@bank, '')));
    SET @bankaccountnumber = LTRIM(RTRIM(ISNULL(@bankaccountnumber, '')));
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

    IF @accounttype = ''
    BEGIN
        RAISERROR('Indique el tipo de cuenta.', 16, 1);
        RETURN;
    END;

    IF @bank = ''
    BEGIN
        RAISERROR('Indique el banco.', 16, 1);
        RETURN;
    END;

    IF @bankaccountnumber = ''
    BEGIN
        RAISERROR('Indique el número de cuenta bancaria.', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @bankaccount IS NULL
    BEGIN
        RAISERROR('Indique el código de cuenta bancaria a actualizar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM te_accounttype (NOLOCK)
        WHERE company = @company
          AND AccountType = @accounttype
    )
    BEGIN
        RAISERROR('Tipo de cuenta no válido para la compañía.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM ERP_Bank (NOLOCK)
        WHERE Company = @company
          AND Bank = @bank
          AND status = 'A'
    )
    BEGIN
        RAISERROR('Banco no válido o inactivo para la compañía.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM TE_BankAccount (NOLOCK)
            WHERE Company = @company
              AND Bank = @bank
              AND BankAccountNumber = @bankaccountnumber
        )
        BEGIN
            RAISERROR('Ya existe una cuenta con el mismo banco y número para la compañía.', 16, 1);
            RETURN;
        END;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'TE_BANKACCOUNT',
            @xlastuser = @xlastuser;

        SELECT @bankaccount_nuevo = id_generado FROM @tabla_id;

        IF @bankaccount_nuevo IS NULL OR LTRIM(RTRIM(@bankaccount_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo de la cuenta bancaria.', 16, 1);
            RETURN;
        END;

        INSERT INTO TE_BankAccount (
            BankAccount,
            AccountType,
            Company,
            Bank,
            BankAccountNumber,
            AccountCurrency,
            Status,
            ReplicationUnit,
            XLastUser,
            XLastDate
        )
        VALUES (
            @bankaccount_nuevo,
            @accounttype,
            @company,
            @bank,
            @bankaccountnumber,
            'LO',
            'A',
            @replicationunit,
            @xlastuser,
            GETDATE()
        );

        SELECT
            @bankaccount_nuevo AS bankaccount,
            'Cuenta bancaria registrada correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM TE_BankAccount (NOLOCK)
        WHERE Company = @company
          AND BankAccount = @bankaccount
    )
    BEGIN
        RAISERROR('No se encontró la cuenta bancaria a actualizar.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM TE_BankAccount (NOLOCK)
        WHERE Company = @company
          AND Bank = @bank
          AND BankAccountNumber = @bankaccountnumber
          AND BankAccount <> @bankaccount
    )
    BEGIN
        RAISERROR('Ya existe otra cuenta con el mismo banco y número para la compañía.', 16, 1);
        RETURN;
    END;

    UPDATE TE_BankAccount
    SET AccountType = @accounttype,
        Bank = @bank,
        BankAccountNumber = @bankaccountnumber,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND BankAccount = @bankaccount;

    SELECT
        @bankaccount AS bankaccount,
        'Cuenta bancaria actualizada correctamente.' AS mensaje;
END
GO
