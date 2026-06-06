/*
    Selector de tipos de cuenta (TE_AccountType) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectortipocuenta_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tat.accounttype AS id,
        LTRIM(RTRIM(tat.description)) AS text
    FROM te_accounttype tat
    WHERE tat.company = @cia
    ORDER BY tat.description ASC;
END
GO
