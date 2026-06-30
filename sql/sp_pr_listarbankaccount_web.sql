/*
    Listado de cuentas bancarias por compañía (maestro Cuentas Bancarias).
    Usado por: POST /api/cuentas-bancarias/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarbankaccount_web]
    @company VARCHAR(4),
    @busqueda VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        ba.BankAccount AS bankaccount,
        ba.BankAccountNumber AS bankaccountnumber,
        ba.AccountType AS accounttype,
        LTRIM(RTRIM(ISNULL(tat.description, ''))) AS accounttype_description,
        ba.Bank AS bank,
        LTRIM(RTRIM(ISNULL(eb.Name, ''))) AS bank_name,
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
      AND (
            @busqueda IS NULL
         OR ba.BankAccountNumber LIKE '%' + @busqueda + '%'
         OR eb.Name LIKE '%' + @busqueda + '%'
         OR tat.description LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        eb.Name ASC,
        ba.BankAccountNumber ASC,
        ba.BankAccount ASC;
END
GO
