/*
    Elimina la carga SUNAT existente (cabecera y filas) para reemplazarla.
    Usado por: POST /api/plame/validar/carga antes de insertar nueva carga.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_sunat_eliminar_carga_web]
    @cia VARCHAR(10),
    @period VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    DELETE FROM PR_PlameSunatCarga
    WHERE Company = @cia
      AND Period = @period;
END
GO
