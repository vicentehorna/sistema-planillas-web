/*
    Selector de carreras (PR_Career) por compañía e institución (PDT).
    El id expuesto es el PDT de la carrera (como en el DW legado costcenter2).

    IMPORTANTE: exige @institution_pdt. Sin institución no se listan carreras
    (cada descripción se repite en muchas instituciones del catálogo).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorcareer_web]
    @cia              VARCHAR(10),
    @institution_pdt  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @institution_pdt = NULLIF(LTRIM(RTRIM(ISNULL(@institution_pdt, ''))), '');

    IF @cia = '' OR @institution_pdt IS NULL
    BEGIN
        SELECT
            CAST(NULL AS VARCHAR(20)) AS id,
            CAST(NULL AS VARCHAR(255)) AS text,
            CAST(NULL AS VARCHAR(20)) AS institution_pdt
        WHERE 1 = 0;
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(c.pdt)) AS id,
        LTRIM(RTRIM(ISNULL(c.description, c.pdt))) AS text,
        LTRIM(RTRIM(i.pdt)) AS institution_pdt
    FROM pr_career c (NOLOCK)
        INNER JOIN pr_institution i (NOLOCK)
            ON i.institution = c.institution
           AND i.company = c.company
    WHERE c.company = @cia
      AND i.pdt = @institution_pdt
      AND NULLIF(LTRIM(RTRIM(ISNULL(c.pdt, ''))), '') IS NOT NULL
    ORDER BY text ASC, id ASC;
END
GO
