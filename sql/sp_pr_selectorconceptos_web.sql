/*
    Selector de conceptos activos por compañía.
    Retorna CONCEPT (código) y DESCRIPTION (texto visible).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorconceptos_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PR_CONCEPT.CONCEPT AS concept,
        PR_CONCEPT.DESCRIPTION AS description
    FROM PR_CONCEPT
    WHERE PR_CONCEPT.STATUS = 'A'
      AND PR_CONCEPT.COMPANY = @cia
    ORDER BY PR_CONCEPT.DESCRIPTION ASC;
END
GO
