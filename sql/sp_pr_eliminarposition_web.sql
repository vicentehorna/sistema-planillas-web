/*
    Elimina un cargo de PR_Position si no está en uso.
    Usado por: POST /api/cargos/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarposition_web]
    @company  VARCHAR(4),
    @position VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @position = LTRIM(RTRIM(ISNULL(@position, '')));

    IF @company = '' OR @position = ''
    BEGIN
        RAISERROR('Indique compañía y cargo a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Position (NOLOCK)
        WHERE Company = @company
          AND Position = @position
    )
    BEGIN
        RAISERROR('El cargo no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Employee (NOLOCK)
        WHERE Position = @position
    )
    BEGIN
        RAISERROR('No se puede eliminar: el cargo está asignado a trabajadores.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeePayroll (NOLOCK)
        WHERE Position = @position
    )
    BEGIN
        RAISERROR('No se puede eliminar: el cargo está referenciado en planillas.', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_Position
    WHERE Company = @company
      AND Position = @position;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar el cargo.', 16, 1);
        RETURN;
    END;

    SELECT
        @position AS position,
        'Cargo eliminado correctamente.' AS mensaje;
END
GO
