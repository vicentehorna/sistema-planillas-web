/*
    Elimina una fórmula completa (detalle + cabecera).
    Usado por: POST /api/formulas/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarformula_web]
    @company       VARCHAR(4),
    @formulaheader VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @formulaheader = LTRIM(RTRIM(ISNULL(@formulaheader, '')));

    IF @company = '' OR @formulaheader = ''
    BEGIN
        RAISERROR('Indique compañía y fórmula a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_FormulaHeader (NOLOCK)
        WHERE Company = @company
          AND FormulaHeader = @formulaheader
    )
    BEGIN
        RAISERROR('La fórmula no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM PR_FormulaDetail
        WHERE FormulaHeader = @formulaheader;

        DELETE FROM PR_FormulaHeader
        WHERE Company = @company
          AND FormulaHeader = @formulaheader;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('No se pudo eliminar la fórmula.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        COMMIT TRANSACTION;

        SELECT
            @formulaheader AS formulaheader,
            'Fórmula eliminada correctamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
