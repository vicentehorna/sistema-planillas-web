/*
    hm_divisa — listado Distribución Porcentual por centro de costo (tipo CC).
    No altera el flujo OT (unidades) de las demás BD.
    Usado por: POST /api/asientos/distribucion-porcentual/listado (solo hm_divisa)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_distribucion_voucher_cc_web]
    @company  VARCHAR(4),
    @period   VARCHAR(20),
    @busqueda VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        d.Fila AS fila,
        LTRIM(RTRIM(ISNULL(d.dni, ''))) AS dni,
        LTRIM(RTRIM(ISNULL(d.nombre, ''))) AS nombre,
        LTRIM(RTRIM(ISNULL(d.codigo, ''))) AS codigo,
        CAST(ROUND(ISNULL(d.valor, 0), 0) AS INT) AS valor,
        LTRIM(RTRIM(ISNULL(d.period, ''))) AS period,
        LTRIM(RTRIM(ISNULL(d.tipo, 'CC'))) AS tipo,
        LTRIM(RTRIM(ISNULL(d.company, ''))) AS company
    FROM PR_DistribucionVoucher d (NOLOCK)
    WHERE d.company = @company
      AND d.period = @period
      AND LTRIM(RTRIM(ISNULL(d.tipo, ''))) = 'CC'
      AND (
            @busqueda IS NULL
         OR d.dni LIKE '%' + @busqueda + '%'
         OR d.nombre LIKE '%' + @busqueda + '%'
         OR d.codigo LIKE '%' + @busqueda + '%'
      )
    ORDER BY d.nombre, d.dni, d.codigo;
END
GO
