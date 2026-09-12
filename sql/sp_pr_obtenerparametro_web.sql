/*
    Detalle de parámetro para edición (maestro Parámetros — PR_Parameter).
    Usado por: POST /api/parametros/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerparametro_web]
    @company    VARCHAR(4),
    @parameter  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @parameter = LTRIM(RTRIM(ISNULL(@parameter, '')));

    SELECT
        p.Parameter AS parameter,
        p.Company AS company,
        LTRIM(RTRIM(ISNULL(p.ShortName, ''))) AS shortname,
        LTRIM(RTRIM(ISNULL(p.Description, ''))) AS description,
        UPPER(LEFT(LTRIM(RTRIM(ISNULL(p.ParameterTypeValue, 'N'))), 1)) AS parametertypevalue,
        LTRIM(RTRIM(ISNULL(p.ParameterTextValue, ''))) AS parametertextvalue,
        p.ParameterNumberValue AS parameternumbervalue,
        p.XLastUser AS xlastuser,
        p.XLastDate AS xlastdate
    FROM PR_Parameter p (NOLOCK)
    WHERE p.Company = @company
      AND p.Parameter = @parameter;
END
GO
