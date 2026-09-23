/*
    Tipos de planilla distintos por descripción (compañías activas).
    @userid:
      NULL  → sin filtro (todas las compañías activas)
      ''    → ninguna (filtro activo sin usuario)
      valor → solo empresas de SY_UserCompany para ese UserID
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorplanillas_consolidada_web]
    @userid VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @filtra BIT = CASE WHEN @userid IS NULL THEN 0 ELSE 1 END;
    DECLARE @uid VARCHAR(30) = LTRIM(RTRIM(ISNULL(@userid, '')));

    SELECT DISTINCT
        LTRIM(RTRIM(PR_PayRollType.Description)) AS tipoplanilla
    FROM PR_PayRollType (NOLOCK)
        INNER JOIN SY_Company (NOLOCK)
            ON SY_Company.Company = PR_PayRollType.Company
           AND SY_Company.status = 'A'
    WHERE LTRIM(RTRIM(ISNULL(PR_PayRollType.Description, ''))) <> ''
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
