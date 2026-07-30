/*
    Elimina una AFP de PR_AFP si no está en uso.
    Usado por: POST /api/afps/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminaraf_web]
    @company VARCHAR(4),
    @afp     VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @afp = LTRIM(RTRIM(ISNULL(@afp, '')));

    IF @company = '' OR @afp = ''
    BEGIN
        RAISERROR('Indique compañía y AFP a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_AFP (NOLOCK)
        WHERE Company = @company
          AND AFP = @afp
    )
    BEGIN
        RAISERROR('La AFP no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Employee (NOLOCK)
        WHERE Company = @company
          AND AFP = @afp
    )
    BEGIN
        RAISERROR('No se puede eliminar: la AFP está asignada a trabajadores.', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID('dbo.PR_EmployeeAFP', 'U') IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM PR_EmployeeAFP (NOLOCK)
            WHERE Company = @company
              AND AFP = @afp
       )
    BEGIN
        RAISERROR('No se puede eliminar: la AFP tiene historial en trabajadores.', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_AFP
    WHERE Company = @company
      AND AFP = @afp;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar la AFP.', 16, 1);
        RETURN;
    END;

    SELECT
        @afp AS afp,
        'AFP eliminada correctamente.' AS mensaje;
END
GO
