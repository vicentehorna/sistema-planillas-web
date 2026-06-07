/*
    Concepto por defecto para Pago de haberes: Neto a recibir (FormulaCode = NETO).
    Usado por: GET /api/selectores/concepto-neto

    Parámetros:
      @cia — compañía (obligatorio).

    Retorna una fila con concept y description, o vacío si no existe.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorconceptoneto_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        LTRIM(RTRIM(PR_CONCEPT.CONCEPT)) AS concept,
        LTRIM(RTRIM(PR_CONCEPT.DESCRIPTION)) AS description
    FROM PR_CONCEPT
    WHERE PR_CONCEPT.STATUS = 'A'
      AND PR_CONCEPT.COMPANY = @cia
      AND UPPER(LTRIM(RTRIM(PR_CONCEPT.FormulaCode))) = 'NETO'
    ORDER BY PR_CONCEPT.CONCEPT;
END
GO
