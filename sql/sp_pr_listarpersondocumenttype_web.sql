/*
    Listado de tipos de documento por compañía (maestro Tipos de Documentos).
    Usado por: POST /api/tipos-documento/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarpersondocumenttype_web]
    @company VARCHAR(4),
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        dt.PersonDocumentType AS persondocumenttype,
        LTRIM(RTRIM(ISNULL(dt.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(dt.PDT, ''))) AS pdt,
        dt.XLastUser AS xlastuser,
        dt.XLastDate AS xlastdate
    FROM SY_PersonDocumentType dt (NOLOCK)
    WHERE dt.Company = @company
      AND (
            @busqueda IS NULL
         OR dt.Description LIKE '%' + @busqueda + '%'
         OR dt.PDT LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        dt.Description ASC,
        dt.PersonDocumentType ASC;
END
GO
