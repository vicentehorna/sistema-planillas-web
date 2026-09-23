/*
    Bancos distintos por nombre en compañías activas.
    @userid: NULL=sin filtro; ''=ninguna; valor=SY_UserCompany.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorbancos_consolidada_web]
    @userid VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @filtra BIT = CASE WHEN @userid IS NULL THEN 0 ELSE 1 END;
    DECLARE @uid VARCHAR(30) = LTRIM(RTRIM(ISNULL(@userid, '')));

    SELECT DISTINCT
        LTRIM(RTRIM(ERP_Bank.Name)) AS name
    FROM ERP_Bank (NOLOCK)
        INNER JOIN SY_Company (NOLOCK)
            ON SY_Company.Company = ERP_Bank.Company
           AND SY_Company.status = 'A'
    WHERE ERP_Bank.status = 'A'
      AND LTRIM(RTRIM(ISNULL(ERP_Bank.Name, ''))) <> ''
      AND (
            @filtra = 0
         OR (
                @uid <> ''
            AND EXISTS (
                    SELECT 1
                    FROM SY_UserCompany uc (NOLOCK)
                    WHERE LTRIM(RTRIM(uc.UserID)) = @uid
                      AND LTRIM(RTRIM(uc.idcompany)) = LTRIM(RTRIM(SY_Company.Company))
                )
            )
          )
    ORDER BY 1 ASC;
END
GO
