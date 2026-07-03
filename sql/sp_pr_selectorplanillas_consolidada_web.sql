/*
    Tipos de planilla distintos por descripción (todas las compañías activas).
    id/text: Description (mismo valor en todas las empresas con esa planilla).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorplanillas_consolidada_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        LTRIM(RTRIM(PR_PayRollType.Description)) AS tipoplanilla
    FROM PR_PayRollType (NOLOCK)
        INNER JOIN SY_Company (NOLOCK)
            ON SY_Company.Company = PR_PayRollType.Company
           AND SY_Company.status = 'A'
    WHERE LTRIM(RTRIM(ISNULL(PR_PayRollType.Description, ''))) <> ''
    ORDER BY 1 ASC;
END
GO
