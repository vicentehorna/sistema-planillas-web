/*
    Selector de instituciones educativas (PR_Institution) por compañía.
    El id expuesto es el PDT (como en el DW legado costcenter1).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorinstitution_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(i.pdt)) AS id,
        LTRIM(RTRIM(ISNULL(i.description, i.pdt))) AS text,
        LTRIM(RTRIM(i.institution)) AS institution
    FROM pr_institution i (NOLOCK)
    WHERE i.company = @cia
      AND NULLIF(LTRIM(RTRIM(ISNULL(i.pdt, ''))), '') IS NOT NULL
    ORDER BY text ASC, id ASC;
END
GO
