/*
    Elimina una cuota pendiente de un préstamo.
    No modifica LoadAmount ni la cuenta corriente; el usuario debe redistribuir
    montos con sp_pr_prestamos_guardar_cuotas_web hasta que la suma = LoadAmount.

    Usado por: POST /api/prestamos/eliminar-cuota
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_eliminar_cuota_web]
    @company         VARCHAR(4),
    @person          VARCHAR(20),
    @loan_secuence   INT,
    @amort_secuence  INT,
    @xlastuser       VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @loadamount      NUMERIC(19, 4),
        @amount          NUMERIC(19, 4),
        @status          VARCHAR(1),
        @cnt_pending     INT,
        @cnt_total       INT,
        @sum_amortized   NUMERIC(19, 4),
        @numberquotes    INT,
        @amountquote     NUMERIC(19, 4),
        @sum_remaining   NUMERIC(19, 4),
        @now             DATETIME;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, 'web'))), 20);
    SET @now = GETDATE();

    IF @company = '' OR @person = '' OR ISNULL(@loan_secuence, 0) <= 0 OR ISNULL(@amort_secuence, 0) <= 0
    BEGIN
        RAISERROR('Indique compañía, trabajador, préstamo y cuota.', 16, 1);
        RETURN;
    END;

    SELECT @loadamount = ROUND(ISNULL(el.LoadAmount, 0), 2)
    FROM PR_EmployeeLoan el WITH (UPDLOCK, HOLDLOCK)
    WHERE el.Company = @company
      AND el.Person = @person
      AND el.Secuence = @loan_secuence;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('El préstamo no existe.', 16, 1);
        RETURN;
    END;

    SELECT
        @amount = ROUND(ISNULL(ea.Amount, 0), 2),
        @status = UPPER(LTRIM(RTRIM(ISNULL(ea.Status, ''))))
    FROM PR_EmployeeLoanAmortization ea WITH (UPDLOCK, HOLDLOCK)
    WHERE ea.Company = @company
      AND ea.Person = @person
      AND ea.Secuence = @amort_secuence
      AND ea.LOANSECUENCE = @loan_secuence;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La cuota no existe o no pertenece al préstamo.', 16, 1);
        RETURN;
    END;

    IF @status <> 'P'
    BEGIN
        RAISERROR('Solo se pueden eliminar cuotas pendientes.', 16, 1);
        RETURN;
    END;

    SELECT
        @cnt_total = COUNT(*),
        @cnt_pending = SUM(CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Status, '')))) = 'P' THEN 1 ELSE 0 END),
        @sum_amortized = ROUND(ISNULL(SUM(
            CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Status, '')))) <> 'P'
                 THEN ISNULL(Amount, 0) ELSE 0 END
        ), 0), 2)
    FROM PR_EmployeeLoanAmortization WITH (UPDLOCK, HOLDLOCK)
    WHERE Company = @company
      AND Person = @person
      AND LOANSECUENCE = @loan_secuence;

    SET @cnt_total = ISNULL(@cnt_total, 0);
    SET @cnt_pending = ISNULL(@cnt_pending, 0);
    SET @sum_amortized = ISNULL(@sum_amortized, 0);

    IF @cnt_total <= 1
    BEGIN
        RAISERROR('No se puede eliminar la única cuota del préstamo.', 16, 1);
        RETURN;
    END;

    IF @cnt_pending <= 1 AND @sum_amortized < @loadamount
    BEGIN
        RAISERROR('No se puede eliminar la última cuota pendiente: aún hay saldo por amortizar.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM PR_EmployeeLoanAmortization
        WHERE Company = @company
          AND Person = @person
          AND Secuence = @amort_secuence
          AND LOANSECUENCE = @loan_secuence
          AND UPPER(LTRIM(RTRIM(ISNULL(Status, '')))) = 'P';

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('No se pudo eliminar la cuota.', 16, 1);
        END;

        SELECT @numberquotes = COUNT(*)
        FROM PR_EmployeeLoanAmortization
        WHERE Company = @company
          AND Person = @person
          AND LOANSECUENCE = @loan_secuence;

        SET @numberquotes = ISNULL(@numberquotes, 0);
        IF @numberquotes > 0
            SET @amountquote = ROUND(@loadamount / CAST(@numberquotes AS NUMERIC(19, 4)), 2);
        ELSE
            SET @amountquote = @loadamount;

        SELECT @sum_remaining = ROUND(ISNULL(SUM(ISNULL(Amount, 0)), 0), 2)
        FROM PR_EmployeeLoanAmortization
        WHERE Company = @company
          AND Person = @person
          AND LOANSECUENCE = @loan_secuence;

        UPDATE PR_EmployeeLoan
        SET NumberQuotes = @numberquotes,
            AMOUNTQUOTE = @amountquote,
            XLastUser = @xlastuser,
            XLastDate = @now
        WHERE Company = @company
          AND Person = @person
          AND Secuence = @loan_secuence;

        COMMIT TRAN;

        SELECT
            @company AS company,
            @person AS person,
            @loan_secuence AS loan_secuence,
            @amort_secuence AS amort_secuence_eliminada,
            @loadamount AS loadamount,
            @sum_remaining AS suma_cuotas,
            @numberquotes AS numberquotes,
            @amountquote AS amountquote,
            'OK' AS resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
        RETURN;
    END CATCH
END
GO
