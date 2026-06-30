/*
    Detalle de cuenta bancaria para edición (maestro Cuentas Bancarias).
    Usado por: POST /api/cuentas-bancarias/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerbankaccount_web]
    @company      VARCHAR(4),
    @bankaccount  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @bankaccount = LTRIM(RTRIM(ISNULL(@bankaccount, '')));

    SELECT
        ba.BankAccount AS bankaccount,
        ba.Company AS company,
        ba.AccountType AS accounttype,
        LTRIM(RTRIM(ISNULL(tat.description, ''))) AS accounttype_description,
        ba.Bank AS bank,
        LTRIM(RTRIM(ISNULL(eb.Name, ''))) AS bank_name,
        ba.BankAccountNumber AS bankaccountnumber,
        ba.XLastUser AS xlastuser,
        ba.XLastDate AS xlastdate
    FROM TE_BankAccount ba (NOLOCK)
        LEFT JOIN te_accounttype tat (NOLOCK)
            ON tat.AccountType = ba.AccountType
           AND tat.company = ba.Company
        LEFT JOIN ERP_Bank eb (NOLOCK)
            ON eb.Bank = ba.Bank
           AND eb.Company = ba.Company
    WHERE ba.Company = @company
      AND ba.BankAccount = @bankaccount;
END
GO
