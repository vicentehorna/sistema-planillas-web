/*
    Selector de tipos de concepto.
    Usado por: GET /api/selectores/concept-types
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorconcepttype_web]
    @cia VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = NULLIF(LTRIM(RTRIM(ISNULL(@cia, ''))), '');

    SELECT
        T.ConceptType AS id,
        LTRIM(RTRIM(
            ISNULL(T.Description, T.ConceptType) +
            CASE WHEN ISNULL(T.ShortName, '') <> ''
                 THEN ' (' + T.ShortName + ')'
                 ELSE ''
            END
        )) AS text,
        T.ShortName AS shortname
    FROM PR_ConceptType T (NOLOCK)
    WHERE @cia IS NULL
       OR T.Company = @cia
       OR T.Company IS NULL
       OR LTRIM(RTRIM(ISNULL(T.Company, ''))) = ''
    ORDER BY
        T.ORDEN,
        T.Description;
END
GO
