/*
    Selector de tipos de planilla por compañía (PR_PayRollType).
    Usado por: GET /api/selectores/planillas (reportes, procesar planilla, etc.).

    id: payrolltype
    text: tipoplanilla (description)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorplanillas_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        PR_PayRollType.PayRollType AS payrolltype,
        PR_PayRollType.Description AS tipoplanilla
    FROM PR_PayRollType (NOLOCK)
    WHERE PR_PayRollType.Company = @cia
    ORDER BY PR_PayRollType.Description ASC;
END
GO
