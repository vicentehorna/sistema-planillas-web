/*
    Maestro Tipo de Día (Tareo) — listado PR_TIPODIA.
    Usado por: POST /api/tareo/tipos-dia/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_tipodia_web]
    @busqueda VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        T.Fila AS fila,
        LTRIM(RTRIM(ISNULL(T.codigo, ''))) AS codigo,
        LTRIM(RTRIM(ISNULL(T.name, ''))) AS nombre,
        CONVERT(decimal(18, 2), ISNULL(T.ValorDefecto, 0)) AS horas,
        LTRIM(RTRIM(ISNULL(T.xlastuser, ''))) AS xlastuser,
        CONVERT(varchar(19), T.xlastdate, 120) AS xlastdate
    FROM PR_TIPODIA T (NOLOCK)
    WHERE (
            @busqueda IS NULL
         OR T.codigo LIKE '%' + @busqueda + '%'
         OR T.name LIKE '%' + @busqueda + '%'
      )
    ORDER BY T.name, T.codigo, T.Fila;
END
GO
