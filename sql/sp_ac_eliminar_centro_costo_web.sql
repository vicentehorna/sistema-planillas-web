/*
    Maestro Centros de Costo — eliminación de AC_CostCenter.
    Usado por: POST /api/centros-costo/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_ac_eliminar_centro_costo_web]
    @company    VARCHAR(4),
    @costcenter VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @costcenter = LTRIM(RTRIM(ISNULL(@costcenter, '')));

    IF NOT EXISTS (
        SELECT 1
        FROM AC_CostCenter (NOLOCK)
        WHERE Company = @company
          AND CostCenter = @costcenter
    )
    BEGIN
        RAISERROR('No se encontró el centro de costo.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Employee (NOLOCK)
        WHERE CostCenter = @costcenter
    )
    BEGIN
        RAISERROR('No se puede eliminar: el centro de costo está asignado a trabajadores.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeePayroll (NOLOCK)
        WHERE CostCenter = @costcenter
    )
    BEGIN
        RAISERROR('No se puede eliminar: el centro de costo está referenciado en planillas.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM AC_CostCenterDistribution (NOLOCK)
        WHERE CostCenter = @costcenter
    )
    BEGIN
        RAISERROR('No se puede eliminar: el centro de costo tiene distribución contable.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM AC_CostCenter (NOLOCK)
        WHERE Company = @company
          AND CostCenter <> @costcenter
          AND (ParentLevel1 = @costcenter OR ParentLevel2 = @costcenter)
    )
    BEGIN
        RAISERROR('No se puede eliminar: el centro de costo es padre de otros centros.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        DELETE FROM AC_CostCenter
        WHERE Company = @company
          AND CostCenter = @costcenter;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 547
            RAISERROR('No se puede eliminar: el centro de costo tiene movimientos o configuraciones relacionadas.', 16, 1);
        ELSE
        BEGIN
            DECLARE @error VARCHAR(4000) = ERROR_MESSAGE();
            RAISERROR('%s', 16, 1, @error);
        END;
        RETURN;
    END CATCH;

    SELECT
        @costcenter AS costcenter,
        'Centro de costo eliminado correctamente.' AS mensaje;
END
GO
