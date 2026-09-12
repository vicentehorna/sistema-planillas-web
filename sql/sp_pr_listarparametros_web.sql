/*
    Listado de parámetros de planilla por compañía (maestro Parámetros).
    Usado por: POST /api/parametros/listado

    Filtros: @company (obligatorio), @busqueda (opcional, ShortName/Description).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarparametros_web]
    @company  VARCHAR(4),
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        p.Parameter AS parameter,
        LTRIM(RTRIM(ISNULL(p.ShortName, ''))) AS shortname,
        LTRIM(RTRIM(ISNULL(p.Description, ''))) AS description,
        UPPER(LEFT(LTRIM(RTRIM(ISNULL(p.ParameterTypeValue, 'N'))), 1)) AS parametertypevalue,
        CASE
            WHEN UPPER(LEFT(LTRIM(RTRIM(ISNULL(p.ParameterTypeValue, 'N'))), 1)) = 'T'
                THEN 'Texto'
            ELSE 'Numérico'
        END AS tipodescription,
        p.XLastDate AS xlastdate
    FROM PR_Parameter p (NOLOCK)
    WHERE p.Company = @company
      AND (
            @busqueda IS NULL
         OR p.ShortName LIKE '%' + @busqueda + '%'
         OR p.Description LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        p.ShortName ASC,
        p.Description ASC;
END
GO
