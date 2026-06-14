/*
    Elimina un registro de PR_VacationDetail y PR_VacationPay;
    recalcula consumeddays en PR_Vacation.
    Usado por: POST /api/vacaciones/eliminar-detalle (registro_vacaciones.html).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_eliminar_detalle_web]
    @company   VARCHAR(4),
    @person    VARCHAR(20),
    @line      INT,
    @secuence  INT,
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_VacationDetail
        WHERE company = @company
          AND person = @person
          AND line = @line
          AND Secuence = @secuence
    )
    BEGIN
        RAISERROR('No se encontró el registro de utilización.', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_VacationPay
    WHERE company = @company
      AND person = @person
      AND line = @line
      AND Secuence = @secuence;

    DELETE FROM PR_VacationDetail
    WHERE company = @company
      AND person = @person
      AND line = @line
      AND Secuence = @secuence;

    UPDATE PR_Vacation
    SET consumeddays = (
            SELECT ISNULL(SUM(Days), 0)
            FROM PR_VacationDetail
            WHERE Person = @person
              AND Company = @company
              AND line = @line
        ),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE company = @company
      AND person = @person
      AND line = @line;

    SELECT 1 AS ok;
END
GO
