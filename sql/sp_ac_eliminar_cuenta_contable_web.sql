/*
    Maestro Cuentas Contables — eliminación de AC_Account.
    Usado por: POST /api/asientos/cuentas-contables/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ac_eliminar_cuenta_contable_web]
    @company VARCHAR(4),
    @account VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @account = LTRIM(RTRIM(ISNULL(@account, '')));

    IF NOT EXISTS (
        SELECT 1
        FROM AC_Account (NOLOCK)
        WHERE Company = @company
          AND Account = @account
    )
    BEGIN
        RAISERROR('No se encontró la cuenta contable.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_AccountProfileDetail (NOLOCK)
        WHERE Company = @company
          AND (DebitAccount = @account OR CreditAccount = @account)
    )
    BEGIN
        RAISERROR('No se puede eliminar: la cuenta está asignada a conceptos contables.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM AC_Account (NOLOCK)
        WHERE Company = @company
          AND Account <> @account
          AND (InflationAccount = @account OR AccountAssociated = @account)
    )
    BEGIN
        RAISERROR('No se puede eliminar: la cuenta está asociada a otra cuenta contable.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        DELETE FROM AC_Account
        WHERE Company = @company
          AND Account = @account;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 547
            RAISERROR('No se puede eliminar: la cuenta tiene movimientos o configuraciones relacionadas.', 16, 1);
        ELSE
        BEGIN
            DECLARE @error VARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR('%s', 16, 1, @error);
        END;
        RETURN;
    END CATCH;

    SELECT
        @account AS account,
        'Cuenta contable eliminada correctamente.' AS mensaje;
END
GO
