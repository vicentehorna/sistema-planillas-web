/*
    Obtiene la configuración PLAME Archivo 14 (PR_CompanyPlame Plame='14')
    de una compañía: horas ordinarias (WH) y horas extras (HE).

    Usado por: GET /api/plame/config-14?cia=
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_companyplame14_obtener_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        p.Company AS company,
        p.line,
        p.Plame AS plame,
        p.Concept AS concept,
        CAST(ISNULL(c.Description, '') AS NVARCHAR(120)) AS description,
        LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) AS formulacode,
        UPPER(LTRIM(RTRIM(ISNULL(p.Type, '')))) AS type,
        UPPER(LTRIM(RTRIM(ISNULL(p.ApplySum, 'P')))) AS applysum
    FROM dbo.PR_CompanyPlame p (NOLOCK)
    LEFT JOIN dbo.PR_Concept c (NOLOCK)
        ON c.Company = p.Company
       AND c.Concept = p.Concept
    WHERE p.Company = @cia
      AND LTRIM(RTRIM(ISNULL(p.Plame, ''))) = '14'
    ORDER BY
        CASE UPPER(LTRIM(RTRIM(ISNULL(p.Type, ''))))
            WHEN 'WH' THEN 1
            WHEN 'HE' THEN 2
            ELSE 9
        END,
        p.line,
        p.Concept;
END
GO
