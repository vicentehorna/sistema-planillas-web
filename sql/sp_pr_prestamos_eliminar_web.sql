/*
    Elimina un préstamo independiente y sus cuotas, solo si TODAS las cuotas
    asociadas están en estado Pendiente ('P').
    Actualiza PR_EmployeeCurrentAccount (resta TotalLoan / TotalPending).

    Usado por: POST /api/prestamos/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_eliminar_web]
    @company   VARCHAR(4),
    @person    VARCHAR(20),
    @secuence  INT,
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @loadamount     NUMERIC(19, 4),
        @currency       VARCHAR(2),
        @exchangerate   NUMERIC(19, 4),
        @loanstatus     VARCHAR(1),
        @cuotas_tot     INT,
        @cuotas_pend    INT,
        @ca_currency    VARCHAR(2),
        @ca_rate        NUMERIC(19, 4),
        @totalloan      NUMERIC(19, 4),
        @totalpending   NUMERIC(19, 4),
        @resta          NUMERIC(19, 4),
        @now            DATETIME;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, 'web'))), 20);
    SET @now = GETDATE();

    IF @company = '' OR @person = '' OR ISNULL(@secuence, 0) <= 0
    BEGIN
        RAISERROR('Indique compañía, trabajador y préstamo.', 16, 1);
        RETURN;
    END;

    SELECT
        @loadamount = ISNULL(el.LoadAmount, 0),
        @currency = UPPER(LTRIM(RTRIM(ISNULL(el.LoadCurrency, 'LO')))),
        @exchangerate = ISNULL(NULLIF(el.ExchangeRate, 0), 1),
        @loanstatus = UPPER(LTRIM(RTRIM(ISNULL(el.Status, ''))))
    FROM PR_EmployeeLoan el WITH (UPDLOCK, HOLDLOCK)
    WHERE el.Company = @company
      AND el.Person = @person
      AND el.Secuence = @secuence;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('El préstamo no existe.', 16, 1);
        RETURN;
    END;

    SELECT
        @cuotas_tot = COUNT(*),
        @cuotas_pend = SUM(CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(Status, '')))) = 'P' THEN 1 ELSE 0 END)
    FROM PR_EmployeeLoanAmortization WITH (UPDLOCK, HOLDLOCK)
    WHERE Company = @company
      AND Person = @person
      AND LOANSECUENCE = @secuence;

    SET @cuotas_tot = ISNULL(@cuotas_tot, 0);
    SET @cuotas_pend = ISNULL(@cuotas_pend, 0);

    IF @cuotas_tot = 0
    BEGIN
        RAISERROR('El préstamo no tiene cuotas para eliminar.', 16, 1);
        RETURN;
    END;

    IF @cuotas_pend < @cuotas_tot
    BEGIN
        RAISERROR('No se puede eliminar: hay cuotas ya amortizadas o no pendientes.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        SELECT
            @ca_currency = CurrentAccountCurrency,
            @ca_rate = ExchangeRate,
            @totalloan = ISNULL(TotalLoan, 0),
            @totalpending = ISNULL(TotalPending, 0)
        FROM PR_EmployeeCurrentAccount WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @company AND Person = @person;

        IF @ca_currency IS NOT NULL
        BEGIN
            IF ISNULL(@ca_rate, 0) <= 0 SET @ca_rate = @exchangerate;
            IF ISNULL(@ca_currency, '') = '' SET @ca_currency = @currency;

            IF @ca_currency = @currency
                SET @resta = @loadamount;
            ELSE IF @ca_currency = 'LO'
                SET @resta = ROUND(@loadamount * @exchangerate, 2);
            ELSE
                SET @resta = ROUND(@loadamount / @exchangerate, 2);

            SET @totalloan = ISNULL(@totalloan, 0) - @resta;
            SET @totalpending = ISNULL(@totalpending, 0) - @resta;
            IF @totalloan < 0 SET @totalloan = 0;
            IF @totalpending < 0 SET @totalpending = 0;

            IF @ca_currency = 'LO'
            BEGIN
                UPDATE PR_EmployeeCurrentAccount
                SET TotalLoan = ROUND(@totalloan, 2),
                    TotalLoanLo = ROUND(@totalloan, 2),
                    TotalLoanEx = ROUND(@totalloan / NULLIF(@ca_rate, 0), 2),
                    TotalPending = ROUND(@totalpending, 2),
                    TotalPendingLo = ROUND(@totalpending, 2),
                    TotalPendingEx = ROUND(@totalpending / NULLIF(@ca_rate, 0), 2),
                    XLastUser = @xlastuser,
                    XLastDate = @now
                WHERE Company = @company AND Person = @person;
            END
            ELSE
            BEGIN
                UPDATE PR_EmployeeCurrentAccount
                SET TotalLoan = ROUND(@totalloan, 2),
                    TotalLoanLo = ROUND(@totalloan * @ca_rate, 2),
                    TotalLoanEx = ROUND(@totalloan, 2),
                    TotalPending = ROUND(@totalpending, 2),
                    TotalPendingLo = ROUND(@totalpending * @ca_rate, 2),
                    TotalPendingEx = ROUND(@totalpending, 2),
                    XLastUser = @xlastuser,
                    XLastDate = @now
                WHERE Company = @company AND Person = @person;
            END;
        END;

        DELETE FROM PR_EmployeeLoanAmortization
        WHERE Company = @company
          AND Person = @person
          AND LOANSECUENCE = @secuence;

        DELETE FROM PR_EmployeeLoan
        WHERE Company = @company
          AND Person = @person
          AND Secuence = @secuence;

        COMMIT TRAN;

        SELECT
            @company AS company,
            @person AS person,
            @secuence AS secuence,
            @cuotas_tot AS cuotas_eliminadas,
            ROUND(ISNULL(@totalpending, 0), 2) AS totalpending,
            ROUND(ISNULL(@totalloan, 0), 2) AS totalloan,
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
