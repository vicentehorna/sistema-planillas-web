/*
    Alias sin sufijo _web por compatibilidad con builds antiguos de la app.
    Delega en sp_pr_listar_historico_fechas_trabajador_web.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_historico_fechas_trabajador]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dbo.sp_pr_listar_historico_fechas_trabajador_web @cia = @cia, @person = @person;
END
GO
