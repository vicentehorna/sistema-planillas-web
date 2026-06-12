/*
    Estado de la carga SUNAT (R01/R04/R05) para compañía y periodo tributario.
    Usado por: GET /api/plame/validar/estado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_sunat_obtener_carga_web]
    @cia VARCHAR(10),
    @period VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    SELECT
        C.CargaId AS cargaid,
        LTRIM(RTRIM(C.Company)) AS company,
        LTRIM(RTRIM(C.Period)) AS period,
        LTRIM(RTRIM(C.Ruc)) AS ruc,
        LTRIM(RTRIM(ISNULL(C.EmployerName, ''))) AS employername,
        LTRIM(RTRIM(ISNULL(C.PeriodoSunat, ''))) AS periodosunat,
        LTRIM(RTRIM(ISNULL(C.FileR01Name, ''))) AS filer01name,
        LTRIM(RTRIM(ISNULL(C.FileR04Name, ''))) AS filer04name,
        LTRIM(RTRIM(ISNULL(C.FileR05Name, ''))) AS filer05name,
        ISNULL(C.RowsR01, 0) AS rowsr01,
        ISNULL(C.RowsR04, 0) AS rowsr04,
        ISNULL(C.RowsR05, 0) AS rowsr05,
        C.UploadedAt AS uploadedat,
        LTRIM(RTRIM(ISNULL(C.UploadedBy, ''))) AS uploadedby
    FROM PR_PlameSunatCarga C (NOLOCK)
    WHERE C.Company = @cia
      AND C.Period = @period;
END
GO
