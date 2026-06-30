/*
    Elimina una cuenta bancaria de TE_BankAccount si no está en uso.
    Usado por: POST /api/cuentas-bancarias/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarbankaccount_web]
    @company     VARCHAR(4),
    @bankaccount VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @bankaccount = LTRIM(RTRIM(ISNULL(@bankaccount, '')));

    IF @company = '' OR @bankaccount = ''
    BEGIN
        RAISERROR('Indique compañía y cuenta bancaria a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM TE_BankAccount (NOLOCK)
        WHERE Company = @company
          AND BankAccount = @bankaccount
    )
    BEGIN
        RAISERROR('La cuenta bancaria no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM TE_ChequeraxBankAccount (NOLOCK)
        WHERE BankAccount = @bankaccount
    )
    BEGIN
        RAISERROR('No se puede eliminar: la cuenta está vinculada a chequeras.', 16, 1);
        RETURN;
    END;

    DELETE FROM TE_BankAccount
    WHERE Company = @company
      AND BankAccount = @bankaccount;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar la cuenta bancaria.', 16, 1);
        RETURN;
    END;

    SELECT
        @bankaccount AS bankaccount,
        'Cuenta bancaria eliminada correctamente.' AS mensaje;
END
GO
