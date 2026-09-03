/*
    Lista histórico de ingresos/ceses (PR_HistoricoFechas) para popup en ficha.
    Usado por: GET /api/trabajadores/historico-fechas
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_historico_fechas_trabajador_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    IF @cia = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía y trabajador.', 16, 1);
        RETURN;
    END

    SELECT
        CONVERT(VARCHAR(10), h.FechaInicio, 23) AS fecha_inicio,
        CASE
            WHEN h.FechaFin IS NULL THEN ''
            ELSE CONVERT(VARCHAR(10), h.FechaFin, 23)
        END AS fecha_fin,
        CASE WHEN h.FechaFin IS NULL THEN 'Y' ELSE 'N' END AS vigente
    FROM dbo.PR_HistoricoFechas h (NOLOCK)
    WHERE h.Company = @cia
      AND h.Person = @person
    ORDER BY h.FechaInicio;
END
GO
