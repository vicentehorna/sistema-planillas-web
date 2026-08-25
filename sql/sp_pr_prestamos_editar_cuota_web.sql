/*
    Edita el importe de una cuota (amortización) pendiente y recalcula:
      - PR_EmployeeLoanAmortization (Amount / AmountTotal y monedas)
      - PR_EmployeeLoan.LoadAmount / AMOUNTQUOTE
      - PR_EmployeeCurrentAccount.TotalLoan / TotalPending (+ LO/EX)

    Solo cuotas con Status = 'P' (Pendiente).

    Usado por: POST /api/prestamos/editar-cuota
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_editar_cuota_web]
    @company         VARCHAR(4),
    @person          VARCHAR(20),
    @amort_secuence  INT,
    @nuevo_monto     NUMERIC(19, 4),
    @xlastuser       VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @loansecuence   INT,
        @old_amount     NUMERIC(19, 4),
        @status         VARCHAR(1),
        @currency       VARCHAR(2),
        @exchangerate   NUMERIC(19, 4),
        @interest       NUMERIC(19, 4),
        @amountlo       NUMERIC(19, 4),
        @amountex       NUMERIC(19, 4),
        @amounttotal    NUMERIC(19, 4),
        @delta          NUMERIC(19, 4),
        @delta_ca       NUMERIC(19, 4),
        @new_loadamount NUMERIC(19, 4),
        @numberquotes   INT,
        @amountquote    NUMERIC(19, 4),
        @loan_currency  VARCHAR(2),
        @loan_rate      NUMERIC(19, 4),
        @loan_amountlo  NUMERIC(19, 4),
        @loan_amountex  NUMERIC(19, 4),
        @ca_currency    VARCHAR(2),
        @ca_rate        NUMERIC(19, 4),
        @totalloan      NUMERIC(19, 4),
        @totalpending   NUMERIC(19, 4),
        @now            DATETIME;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, 'web'))), 20);
    SET @now = GETDATE();
    SET @nuevo_monto = ROUND(ISNULL(@nuevo_monto, 0), 2);

    IF @company = '' OR @person = '' OR ISNULL(@amort_secuence, 0) <= 0
    BEGIN
        RAISERROR('Indique compañía, trabajador y cuota.', 16, 1);
        RETURN;
    END;

    IF @nuevo_monto <= 0
    BEGIN
        RAISERROR('El monto de la cuota debe ser mayor a cero.', 16, 1);
        RETURN;
    END;

    SELECT
        @loansecuence = CONVERT(INT, ISNULL(ea.LOANSECUENCE, 0)),
        @old_amount = ISNULL(ea.Amount, 0),
        @status = UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))),
        @currency = UPPER(LTRIM(RTRIM(ISNULL(ea.AmortizationCurrency, 'LO')))),
        @exchangerate = ISNULL(NULLIF(ea.ExchangeRate, 0), 1),
        @interest = ISNULL(ea.INTEREST, 0)
    FROM PR_EmployeeLoanAmortization ea WITH (UPDLOCK, HOLDLOCK)
    WHERE ea.Company = @company
      AND ea.Person = @person
      AND ea.Secuence = @amort_secuence;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La cuota no existe.', 16, 1);
        RETURN;
    END;

    IF @status <> 'P'
    BEGIN
        RAISERROR('Solo se puede editar el monto de cuotas pendientes.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@loansecuence, 0) <= 0
    BEGIN
        RAISERROR('La cuota no está asociada a un préstamo.', 16, 1);
        RETURN;
    END;

    IF ROUND(@old_amount, 2) = @nuevo_monto
    BEGIN
        SELECT
            @company AS company,
            @person AS person,
            @amort_secuence AS amort_secuence,
            @loansecuence AS loansecuence,
            @nuevo_monto AS amount,
            ISNULL(el.LoadAmount, 0) AS loadamount,
            ISNULL(el.AMOUNTQUOTE, 0) AS amountquote,
            ISNULL(ca.TotalPending, 0) AS totalpending,
            ISNULL(ca.TotalLoan, 0) AS totalloan,
            'OK' AS resultado
        FROM PR_EmployeeLoan el (NOLOCK)
            LEFT JOIN PR_EmployeeCurrentAccount ca (NOLOCK)
                ON ca.Company = el.Company AND ca.Person = el.Person
        WHERE el.Company = @company
          AND el.Person = @person
          AND el.Secuence = @loansecuence;
        RETURN;
    END;

    SET @delta = @nuevo_monto - ROUND(@old_amount, 2);
    SET @amounttotal = ROUND(@nuevo_monto + ISNULL(@interest, 0), 2);

    IF @currency = 'LO'
    BEGIN
        SET @amountlo = @nuevo_monto;
        SET @amountex = ROUND(@nuevo_monto / @exchangerate, 2);
    END
    ELSE
    BEGIN
        SET @amountlo = ROUND(@nuevo_monto * @exchangerate, 2);
        SET @amountex = @nuevo_monto;
    END;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE PR_EmployeeLoanAmortization
        SET Amount = @nuevo_monto,
            AmountLo = @amountlo,
            AmountEx = @amountex,
            AMOUNTTOTAL = @amounttotal,
            AMOUNTTOTALLO = @amountlo,
            AMOUNTTOTALEX = @amountex,
            XLastUser = @xlastuser,
            XLastDate = @now
        WHERE Company = @company
          AND Person = @person
          AND Secuence = @amort_secuence;

        SELECT
            @new_loadamount = ROUND(SUM(ISNULL(Amount, 0)), 2),
            @numberquotes = COUNT(*)
        FROM PR_EmployeeLoanAmortization WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @company
          AND Person = @person
          AND LOANSECUENCE = @loansecuence;

        SET @new_loadamount = ISNULL(@new_loadamount, 0);
        SET @numberquotes = ISNULL(@numberquotes, 0);
        IF @numberquotes > 0
            SET @amountquote = ROUND(@new_loadamount / CAST(@numberquotes AS NUMERIC(19, 4)), 2);
        ELSE
            SET @amountquote = @nuevo_monto;

        SELECT
            @loan_currency = UPPER(LTRIM(RTRIM(ISNULL(el.LoadCurrency, @currency)))),
            @loan_rate = ISNULL(NULLIF(el.ExchangeRate, 0), @exchangerate)
        FROM PR_EmployeeLoan el WITH (UPDLOCK, HOLDLOCK)
        WHERE el.Company = @company
          AND el.Person = @person
          AND el.Secuence = @loansecuence;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('El préstamo asociado no existe.', 16, 1);
        END;

        IF @loan_currency = 'LO'
        BEGIN
            SET @loan_amountlo = @new_loadamount;
            SET @loan_amountex = ROUND(@new_loadamount / @loan_rate, 2);
        END
        ELSE
        BEGIN
            SET @loan_amountlo = ROUND(@new_loadamount * @loan_rate, 2);
            SET @loan_amountex = @new_loadamount;
        END;

        UPDATE PR_EmployeeLoan
        SET LoadAmount = @new_loadamount,
            LoadAmountLo = @loan_amountlo,
            LoadAmountEx = @loan_amountex,
            AMOUNTQUOTE = @amountquote,
            XLastUser = @xlastuser,
            XLastDate = @now
        WHERE Company = @company
          AND Person = @person
          AND Secuence = @loansecuence;

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
                SET @delta_ca = @delta;
            ELSE IF @ca_currency = 'LO'
                SET @delta_ca = ROUND(@delta * @exchangerate, 2);
            ELSE
                SET @delta_ca = ROUND(@delta / @exchangerate, 2);

            SET @totalloan = ISNULL(@totalloan, 0) + @delta_ca;
            SET @totalpending = ISNULL(@totalpending, 0) + @delta_ca;
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

        COMMIT TRAN;

        SELECT
            @company AS company,
            @person AS person,
            @amort_secuence AS amort_secuence,
            @loansecuence AS loansecuence,
            @nuevo_monto AS amount,
            @new_loadamount AS loadamount,
            @amountquote AS amountquote,
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
