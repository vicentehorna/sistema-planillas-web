/*
    Registra un préstamo independiente por número de cuotas + genera amortizaciones.
    Replica lógica de w_pr_loan_edit / wf_generate_loan + wf_generate_quotes (PB9).

    Fijos:
      LoanClass = 'I', LoanType = 'P', QuoteGeneration = 'C', RateInterest = 0
      FlagLiquidation cuotas = 'F' (Fin de Mes)
      Centro de costo = del trabajador

    Usado por: POST /api/prestamos/registrar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_registrar_web]
    @company        VARCHAR(4),
    @person         VARCHAR(20),
    @loanreason     VARCHAR(20),
    @loadamount     NUMERIC(19, 4),
    @loadcurrency   VARCHAR(2) = 'LO',
    @exchangerate   NUMERIC(19, 4) = 1,
    @loandate       VARCHAR(10),
    @numberquotes   INT,
    @prperiod_ini   VARCHAR(10),
    @reference      VARCHAR(50) = NULL,
    @xlastuser      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @payrolltype       VARCHAR(20),
        @currency          VARCHAR(2),
        @costcenter        VARCHAR(20),
        @costcentercode    VARCHAR(20),
        @replicationunit   VARCHAR(4),
        @loanperiod        VARCHAR(10),
        @loansecuence      INT,
        @amortsecuence     INT,
        @quoteamount       NUMERIC(19, 4),
        @quote_i           NUMERIC(19, 4),
        @amountlo          NUMERIC(19, 4),
        @amountex          NUMERIC(19, 4),
        @totalloan         NUMERIC(19, 4),
        @totalpending      NUMERIC(19, 4),
        @ca_currency       VARCHAR(2),
        @ca_rate           NUMERIC(19, 4),
        @ca_exists         INT,
        @i                 INT,
        @periodorder       INT,
        @period_i          VARCHAR(10),
        @sdate             VARCHAR(8),
        @now               DATETIME,
        @ref               VARCHAR(50),
        @loandate_dt       DATETIME;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @loanreason = LTRIM(RTRIM(ISNULL(@loanreason, '')));
    SET @loadcurrency = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@loadcurrency, 'LO'))), 2));
    SET @prperiod_ini = REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@prperiod_ini, ''))), '-', ''), '/', '');
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, 'web'))), 20);
    SET @ref = LEFT(LTRIM(RTRIM(ISNULL(@reference, ''))), 50);
    SET @now = GETDATE();

    SET @sdate = REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@loandate, ''))), '-', ''), '/', '');
    IF LEN(@sdate) >= 8 AND ISNUMERIC(LEFT(@sdate, 8)) = 1
        SET @loandate_dt = CONVERT(DATETIME, LEFT(@sdate, 8), 112);
    ELSE
        SET @loandate_dt = NULL;
    SET @sdate = CONVERT(VARCHAR(8), ISNULL(@loandate_dt, '19000101'), 112);

    IF @company = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía y trabajador.', 16, 1);
        RETURN;
    END;
    IF @loanreason = ''
    BEGIN
        RAISERROR('Seleccione el motivo del préstamo.', 16, 1);
        RETURN;
    END;
    IF @loandate_dt IS NULL
    BEGIN
        RAISERROR('Indique la fecha del préstamo.', 16, 1);
        RETURN;
    END;
    IF ISNULL(@loadamount, 0) <= 0
    BEGIN
        RAISERROR('El monto del préstamo debe ser mayor a cero.', 16, 1);
        RETURN;
    END;
    IF ISNULL(@numberquotes, 0) <= 0
    BEGIN
        RAISERROR('El número de cuotas debe ser mayor a cero.', 16, 1);
        RETURN;
    END;
    IF LEN(@prperiod_ini) < 8 OR ISNUMERIC(@prperiod_ini) = 0
    BEGIN
        RAISERROR('Indique un periodo inicial válido (YYYY-MM-DD).', 16, 1);
        RETURN;
    END;
    SET @prperiod_ini = LEFT(@prperiod_ini, 8);

    IF @loadcurrency NOT IN ('LO', 'EX') SET @loadcurrency = 'LO';
    IF ISNULL(@exchangerate, 0) <= 0 SET @exchangerate = 1;

    IF NOT EXISTS (
        SELECT 1 FROM PR_LoanReason (NOLOCK)
        WHERE Company = @company AND LoanReason = @loanreason
    )
    BEGIN
        RAISERROR('El motivo de préstamo no existe para la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        @payrolltype = LTRIM(RTRIM(e.PayRollType)),
        @costcenter = LTRIM(RTRIM(e.CostCenter)),
        @costcentercode = LTRIM(RTRIM(e.Costcentername)),
        @replicationunit = LTRIM(RTRIM(e.ReplicationUnit)),
        @currency = UPPER(LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(e.SalaryCurrency)), ''), @loadcurrency))))
    FROM PR_Employee e (NOLOCK)
    WHERE e.Company = @company
      AND e.Person = @person
      AND e.Status = 'N';

    IF @payrolltype IS NULL
    BEGIN
        RAISERROR('Trabajador no encontrado o inactivo.', 16, 1);
        RETURN;
    END;

    /* Moneda del préstamo: usa la enviada (default LO / soles) */
    SET @currency = @loadcurrency;

    /* Periodo del encabezado según fecha del préstamo */
    SELECT TOP 1 @loanperiod = LTRIM(RTRIM(pr.PRPeriod))
    FROM PR_Period pr (NOLOCK)
    WHERE pr.Company = @company
      AND pr.PayRollType = @payrolltype
      AND @sdate BETWEEN CONVERT(VARCHAR(8), pr.DateBegin, 112)
                     AND CONVERT(VARCHAR(8), pr.DateEnd, 112)
    ORDER BY pr.PeriodOrder;

    IF @loanperiod IS NULL
    BEGIN
        RAISERROR('No existe periodo configurado para la fecha del préstamo.', 16, 1);
        RETURN;
    END;

    /* Validar periodo inicial y disponibilidad de N periodos consecutivos */
    IF NOT EXISTS (
        SELECT 1 FROM PR_Period (NOLOCK)
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND PRPeriod = @prperiod_ini
    )
    BEGIN
        RAISERROR('El periodo inicial no existe en la planilla del trabajador.', 16, 1);
        RETURN;
    END;

    ;WITH periodos AS (
        SELECT
            pr.PRPeriod,
            pr.PeriodOrder,
            ROW_NUMBER() OVER (ORDER BY pr.PeriodOrder) AS rn
        FROM PR_Period pr (NOLOCK)
        WHERE pr.Company = @company
          AND pr.PayRollType = @payrolltype
          AND pr.PeriodOrder >= (
                SELECT PeriodOrder
                FROM PR_Period (NOLOCK)
                WHERE Company = @company
                  AND PayRollType = @payrolltype
                  AND PRPeriod = @prperiod_ini
            )
    )
    SELECT @i = COUNT(*) FROM periodos WHERE rn <= @numberquotes;

    IF ISNULL(@i, 0) < @numberquotes
    BEGIN
        RAISERROR('No hay periodos suficientes configurados para el número de cuotas.', 16, 1);
        RETURN;
    END;

    SET @quoteamount = ROUND(@loadamount / CAST(@numberquotes AS NUMERIC(19, 4)), 2);

    BEGIN TRY
        BEGIN TRAN;

        /* --- Cuenta corriente --- */
        SELECT
            @ca_exists = 1,
            @ca_currency = CurrentAccountCurrency,
            @ca_rate = ExchangeRate,
            @totalloan = ISNULL(TotalLoan, 0),
            @totalpending = ISNULL(TotalPending, 0)
        FROM PR_EmployeeCurrentAccount WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @company AND Person = @person;

        IF @ca_exists IS NULL
        BEGIN
            SET @ca_currency = @currency;
            SET @ca_rate = @exchangerate;
            SET @totalloan = 0;
            SET @totalpending = 0;

            INSERT INTO PR_EmployeeCurrentAccount (
                Person, Company, CurrentAccountCurrency, ExchangeRate,
                TotalLoan, TotalLoanLo, TotalLoanEx,
                TotalPayed, TotalPayedLo, TotalPayedEx,
                TotalPending, TotalPendingLo, TotalPendingEx,
                ReplicationUnit, XLastUser, XLastDate
            )
            VALUES (
                @person, @company, @ca_currency, @ca_rate,
                0, 0, 0,
                0, 0, 0,
                0, 0, 0,
                @replicationunit, @xlastuser, @now
            );
        END
        ELSE
        BEGIN
            IF @ca_rate IS NULL OR @ca_rate <= 0 SET @ca_rate = @exchangerate;
            IF ISNULL(@ca_currency, '') = '' SET @ca_currency = @currency;
        END;

        /* Sumar monto a totales (misma moneda de cuenta o conversión) */
        IF @ca_currency = @currency
        BEGIN
            SET @totalloan = ISNULL(@totalloan, 0) + @loadamount;
            SET @totalpending = ISNULL(@totalpending, 0) + @loadamount;
        END
        ELSE IF @ca_currency = 'LO'
        BEGIN
            SET @totalloan = ISNULL(@totalloan, 0) + ROUND(@loadamount * @exchangerate, 2);
            SET @totalpending = ISNULL(@totalpending, 0) + ROUND(@loadamount * @exchangerate, 2);
        END
        ELSE
        BEGIN
            SET @totalloan = ISNULL(@totalloan, 0) + ROUND(@loadamount / @exchangerate, 2);
            SET @totalpending = ISNULL(@totalpending, 0) + ROUND(@loadamount / @exchangerate, 2);
        END;

        IF @totalloan < 0 OR @totalpending < 0
        BEGIN
            RAISERROR('Inconsistencia en los montos de la cuenta corriente.', 16, 1);
        END;

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

        /* --- Encabezado préstamo --- */
        SELECT @loansecuence = ISNULL(MAX(Secuence), 0) + 1
        FROM PR_EmployeeLoan WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @company AND Person = @person;

        IF @currency = 'LO'
        BEGIN
            SET @amountlo = @loadamount;
            SET @amountex = ROUND(@loadamount / @exchangerate, 2);
        END
        ELSE
        BEGIN
            SET @amountlo = ROUND(@loadamount * @exchangerate, 2);
            SET @amountex = @loadamount;
        END;

        INSERT INTO PR_EmployeeLoan (
            Person, Company, Secuence, LoanReason, LoanDate, PRPeriod,
            LoanType, LoadCurrency, ExchangeRate,
            LoadAmount, LoadAmountLo, LoadAmountEx,
            NumberQuotes, CostCenter, CostCenterCode, Reference,
            Status, ReplicationUnit, XLastUser, XLastDate,
            LOANCLASS, QUOTEGENERATION, AMOUNTQUOTE, RATEINTEREST
        )
        VALUES (
            @person, @company, @loansecuence, @loanreason, @loandate_dt, @loanperiod,
            'P', @currency, @exchangerate,
            @loadamount, @amountlo, @amountex,
            @numberquotes, @costcenter, @costcentercode, NULLIF(@ref, ''),
            'P', @replicationunit, @xlastuser, @now,
            'I', 'C', @quoteamount, 0
        );

        /* --- Cuotas --- */
        SELECT @amortsecuence = ISNULL(MAX(Secuence), 0)
        FROM PR_EmployeeLoanAmortization WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @company AND Person = @person;

        DECLARE @periodos TABLE (
            rn INT PRIMARY KEY,
            prperiod VARCHAR(10),
            periodorder INT
        );

        INSERT INTO @periodos (rn, prperiod, periodorder)
        SELECT
            ROW_NUMBER() OVER (ORDER BY pr.PeriodOrder),
            LTRIM(RTRIM(pr.PRPeriod)),
            pr.PeriodOrder
        FROM PR_Period pr (NOLOCK)
        WHERE pr.Company = @company
          AND pr.PayRollType = @payrolltype
          AND pr.PeriodOrder >= (
                SELECT PeriodOrder
                FROM PR_Period (NOLOCK)
                WHERE Company = @company
                  AND PayRollType = @payrolltype
                  AND PRPeriod = @prperiod_ini
            );

        SET @i = 1;
        WHILE @i <= @numberquotes
        BEGIN
            SELECT @period_i = prperiod FROM @periodos WHERE rn = @i;
            IF @period_i IS NULL
            BEGIN
                RAISERROR('No hay periodos suficientes configurados para el número de cuotas.', 16, 1);
            END;

            IF @i = @numberquotes
                SET @quote_i = ROUND(@loadamount - (@quoteamount * (@numberquotes - 1)), 2);
            ELSE
                SET @quote_i = @quoteamount;

            IF @currency = 'LO'
            BEGIN
                SET @amountlo = @quote_i;
                SET @amountex = ROUND(@quote_i / @exchangerate, 2);
            END
            ELSE
            BEGIN
                SET @amountlo = ROUND(@quote_i * @exchangerate, 2);
                SET @amountex = @quote_i;
            END;

            SET @amortsecuence = @amortsecuence + 1;

            INSERT INTO PR_EmployeeLoanAmortization (
                Person, Company, Secuence, PRperiod,
                AmortizationCurrency, ExchangeRate,
                Amount, AmountLo, AmountEx,
                CostCenter, CostCenterCode,
                Status, ReplicationUnit, XLastUser, XLastDate,
                LOANSECUENCE, INTEREST, INTERESTLO, INTERESTEX,
                AMOUNTTOTAL, AMOUNTTOTALLO, AMOUNTTOTALEX,
                flagliquidation, comments
            )
            VALUES (
                @person, @company, @amortsecuence, @period_i,
                @currency, @exchangerate,
                @quote_i, @amountlo, @amountex,
                @costcenter, @costcentercode,
                'P', @replicationunit, @xlastuser, @now,
                @loansecuence, 0, 0, 0,
                @quote_i, @amountlo, @amountex,
                'F', NULL
            );

            SET @i = @i + 1;
        END;

        COMMIT TRAN;

        SELECT
            @company AS company,
            @person AS person,
            @loansecuence AS secuence,
            @loanperiod AS prperiod_loan,
            @prperiod_ini AS prperiod_ini,
            @numberquotes AS numberquotes,
            @quoteamount AS amountquote,
            @loadamount AS loadamount,
            ROUND(@totalpending, 2) AS totalpending,
            ROUND(@totalloan, 2) AS totalloan,
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
