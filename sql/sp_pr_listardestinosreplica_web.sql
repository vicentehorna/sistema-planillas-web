/*
    Empresas que pueden recibir la réplica de maestros de @company_base.
    Usado por: GET /api/empresas/destinos-replica

    Solo empresas sin trabajadores y distintas del origen; primero las que aún no tienen conceptos
    y luego las más recientes. conceptos/formulas > 0 indica que la réplica reemplazará lo existente.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listardestinosreplica_web]
    @company_base VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company_base = LTRIM(RTRIM(ISNULL(@company_base, '')));

    CREATE TABLE #formulas (Company VARCHAR(4) COLLATE DATABASE_DEFAULT PRIMARY KEY, total INT);
    IF OBJECT_ID('dbo.PR_FormulaHeader', 'U') IS NOT NULL
        EXEC sp_executesql N'INSERT INTO #formulas (Company, total)
            SELECT Company, COUNT(*) FROM PR_FormulaHeader (NOLOCK) WHERE Company IS NOT NULL GROUP BY Company;';

    SELECT
        LTRIM(RTRIM(C.Company)) AS company,
        LTRIM(RTRIM(ISNULL(C.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(C.RUC, ''))) AS ruc,
        UPPER(LTRIM(RTRIM(ISNULL(C.Status, 'A')))) AS status,
        ISNULL(K.total, 0) AS conceptos,
        ISNULL(F.total, 0) AS formulas,
        C.XCreateDate AS xcreatedate
    FROM SY_Company C (NOLOCK)
    LEFT JOIN (
        SELECT Company, COUNT(*) AS total FROM PR_Concept (NOLOCK) GROUP BY Company
    ) K ON K.Company = C.Company
    LEFT JOIN #formulas F ON F.Company = C.Company
    WHERE C.Company <> @company_base
      AND NOT EXISTS (SELECT 1 FROM PR_Employee E (NOLOCK) WHERE E.Company = C.Company)
    ORDER BY
        CASE WHEN ISNULL(K.total, 0) = 0 THEN 0 ELSE 1 END,
        C.XCreateDate DESC,
        C.Company DESC;
END
GO
