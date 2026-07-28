/*
    Selector de todos los tipos de proceso de una compañía (PR_ProcessType).
    Usado por: GET /api/selectores/procesos-todos?cia=
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesostodos_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(pt.ProcessType)) AS processtype,
        LTRIM(RTRIM(ISNULL(pt.Description, pt.ProcessType))) AS proceso,
        LTRIM(RTRIM(ISNULL(pt.ShortName, ''))) AS shortname
    FROM PR_ProcessType pt (NOLOCK)
    WHERE pt.Company = @cia
    ORDER BY pt.Description ASC, pt.ProcessType ASC;
END
GO
