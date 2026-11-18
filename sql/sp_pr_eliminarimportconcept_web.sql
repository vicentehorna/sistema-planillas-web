/*
    Elimina una plantilla de importación (cabecera + detalle) de una compañía.

    Usado por: POST /api/plantillas-importacion/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarimportconcept_web]
    @company       VARCHAR(4),
    @importconcept VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @importconcept = LTRIM(RTRIM(ISNULL(@importconcept, '')));

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @importconcept = ''
    BEGIN
        RAISERROR('Indique la plantilla a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.PR_ImportConcept (NOLOCK)
        WHERE Company = @company
          AND ImportConcept = @importconcept
    )
    BEGIN
        RAISERROR('La plantilla no existe en la compañía.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        /* Legacy: Detail.Company puede ser NULL; borrar por ImportConcept + cia/vacío. */
        DELETE FROM dbo.PR_ImportConceptDetail
        WHERE ImportConcept = @importconcept
          AND (
                ISNULL(LTRIM(RTRIM(Company)), '') = ''
             OR Company = @company
          );

        DELETE FROM dbo.PR_ImportConcept
        WHERE Company = @company
          AND ImportConcept = @importconcept;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
        RETURN;
    END CATCH;

    SELECT
        CAST(1 AS BIT) AS ok,
        @company AS company,
        @importconcept AS importconcept,
        N'Plantilla eliminada correctamente.' AS mensaje;
END
GO
