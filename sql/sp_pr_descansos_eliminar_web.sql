/*
    Elimina un registro de PR_EmployeeMedicalRest por clave (Company, Person, line).
    Usado por: POST /descansos/eliminar (registro_descansos_medicos.html).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_descansos_eliminar_web]
    @company   VARCHAR(4),
    @person    VARCHAR(20),
    @line      INT,
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @adjunto VARCHAR(255);

    IF @line IS NULL OR @line <= 0
    BEGIN
        RAISERROR('Indique el registro de descanso a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_EmployeeMedicalRest
        WHERE Company = @company
          AND Person = @person
          AND line = @line
    )
    BEGIN
        RAISERROR('No se encontró el registro de descanso médico.', 16, 1);
        RETURN;
    END;

    SELECT @adjunto = adjunto
    FROM PR_EmployeeMedicalRest
    WHERE Company = @company
      AND Person = @person
      AND line = @line;

    DELETE FROM PR_EmployeeMedicalRest
    WHERE Company = @company
      AND Person = @person
      AND line = @line;

    SELECT 1 AS ok, @adjunto AS adjunto;
END
GO
