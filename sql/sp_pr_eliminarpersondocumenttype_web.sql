/*
    Elimina un tipo de documento de SY_PersonDocumentType si no está en uso.
    Usado por: POST /api/tipos-documento/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarpersondocumenttype_web]
    @company              VARCHAR(4),
    @persondocumenttype   VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @persondocumenttype = LTRIM(RTRIM(ISNULL(@persondocumenttype, '')));

    IF @company = '' OR @persondocumenttype = ''
    BEGIN
        RAISERROR('Indique compañía y tipo de documento a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM SY_PersonDocumentType (NOLOCK)
        WHERE Company = @company
          AND PersonDocumentType = @persondocumenttype
    )
    BEGIN
        RAISERROR('El tipo de documento no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM SY_Person (NOLOCK)
        WHERE EmployeeDocumentType = @persondocumenttype
           OR DocumentType = @persondocumenttype
    )
    BEGIN
        RAISERROR('No se puede eliminar: el tipo de documento está asignado a personas.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM SY_Company (NOLOCK)
        WHERE Rep_DocType = @persondocumenttype
    )
    BEGIN
        RAISERROR('No se puede eliminar: el tipo de documento está configurado en una compañía.', 16, 1);
        RETURN;
    END;

    DELETE FROM SY_PersonDocumentType
    WHERE Company = @company
      AND PersonDocumentType = @persondocumenttype;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar el tipo de documento.', 16, 1);
        RETURN;
    END;

    SELECT
        @persondocumenttype AS persondocumenttype,
        'Tipo de documento eliminado correctamente.' AS mensaje;
END
GO
