/*
    Bancos distintos por nombre en todas las compañías activas.
    id/text: Name (se resuelve a Bank por compañía al filtrar).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorbancos_consolidada_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        LTRIM(RTRIM(ERP_Bank.Name)) AS name
    FROM ERP_Bank (NOLOCK)
        INNER JOIN SY_Company (NOLOCK)
            ON SY_Company.Company = ERP_Bank.Company
           AND SY_Company.status = 'A'
    WHERE ERP_Bank.status = 'A'
      AND LTRIM(RTRIM(ISNULL(ERP_Bank.Name, ''))) <> ''
    ORDER BY 1 ASC;
END
GO
