/*
    Detalle de tipo de documento para edición (maestro Tipos de Documentos).
    Usado por: POST /api/tipos-documento/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerpersondocumenttype_web]
    @company              VARCHAR(4),
    @persondocumenttype   VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @persondocumenttype = LTRIM(RTRIM(ISNULL(@persondocumenttype, '')));

    SELECT
        dt.PersonDocumentType AS persondocumenttype,
        dt.Company AS company,
        LTRIM(RTRIM(ISNULL(dt.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(dt.PDT, ''))) AS pdt,
        dt.XLastUser AS xlastuser,
        dt.XLastDate AS xlastdate
    FROM SY_PersonDocumentType dt (NOLOCK)
    WHERE dt.Company = @company
      AND dt.PersonDocumentType = @persondocumenttype;
END
GO
