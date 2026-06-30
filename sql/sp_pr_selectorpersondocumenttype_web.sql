/*
    Selector de tipos de documento de persona (SY_PersonDocumentType) por compañía.
    Usado por: GET /api/selectores/tipos-documento-persona?cia=...
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpersondocumenttype_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        dt.PersonDocumentType AS id,
        LTRIM(RTRIM(ISNULL(dt.Description, ''))) AS text
    FROM SY_PersonDocumentType dt (NOLOCK)
    WHERE dt.Company = @cia
    ORDER BY dt.Description ASC, dt.PersonDocumentType ASC;
END
GO
