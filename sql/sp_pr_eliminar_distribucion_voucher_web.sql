/*
    Maestro Distribución Porcentual — eliminación de PR_DistribucionVoucher.
    Usado por: POST /api/asientos/distribucion-porcentual/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_distribucion_voucher_web]
    @company VARCHAR(4),
    @period  VARCHAR(20),
    @fila    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    IF @fila IS NULL OR @company = '' OR @period = ''
    BEGIN
        RAISERROR('Indique compañía, periodo y registro a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_DistribucionVoucher (NOLOCK)
        WHERE Fila = @fila
          AND company = @company
          AND period = @period
    )
    BEGIN
        RAISERROR('No se encontró el registro de distribución.', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_DistribucionVoucher
    WHERE Fila = @fila
      AND company = @company
      AND period = @period;

    SELECT
        @fila AS fila,
        'Distribución eliminada correctamente.' AS mensaje;
END
GO
