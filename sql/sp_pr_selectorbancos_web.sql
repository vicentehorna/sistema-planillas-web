/*
    Selector de bancos activos por compañía (ERP_Bank).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorbancos_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ERP_Bank.Bank AS bank,
        ERP_Bank.Name AS name
    FROM ERP_Bank
    WHERE ERP_Bank.status = 'A'
      AND ERP_Bank.Company = @cia
    ORDER BY ERP_Bank.Name ASC;
END
GO
