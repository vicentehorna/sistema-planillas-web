/*
    Listado de compañías con estado de logo/firma (sin devolver VARBINARY).
    Usado por: Configuración → Generales → Logo y Firma.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_companias_branding_web]
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        LTRIM(RTRIM(c.Company)) AS company,
        LTRIM(RTRIM(ISNULL(c.Description, c.Company))) AS description,
        LTRIM(RTRIM(ISNULL(c.logoname, ''))) AS logoname,
        LTRIM(RTRIM(ISNULL(c.signaturename, ''))) AS signaturename,
        CASE
            WHEN c.logo_data IS NOT NULL AND DATALENGTH(c.logo_data) > 0 THEN CAST(1 AS INT)
            ELSE CAST(0 AS INT)
        END AS has_logo_blob,
        CASE
            WHEN c.signature_data IS NOT NULL AND DATALENGTH(c.signature_data) > 0 THEN CAST(1 AS INT)
            ELSE CAST(0 AS INT)
        END AS has_firma_blob,
        LTRIM(RTRIM(ISNULL(c.logo_contenttype, ''))) AS logo_contenttype,
        LTRIM(RTRIM(ISNULL(c.signature_contenttype, ''))) AS signature_contenttype,
        ISNULL(c.Status, 'A') AS status
    FROM dbo.SY_Company c (NOLOCK)
    WHERE (
            @busqueda IS NULL
         OR c.Company LIKE '%' + @busqueda + '%'
         OR ISNULL(c.Description, '') LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        LTRIM(RTRIM(ISNULL(c.Description, c.Company))) ASC,
        LTRIM(RTRIM(c.Company)) ASC;
END
GO
