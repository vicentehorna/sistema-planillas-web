/*
    Guarda montos de varias cuotas pendientes de un préstamo en una sola operación.
    Valida que la suma de TODAS las cuotas (pagadas fijas + pendientes editadas)
    sea exactamente igual al importe del préstamo (LoadAmount).
    No modifica LoadAmount ni la cuenta corriente (solo redistribuye cuotas).

    @cuotas_text: "secuence:amount|secuence:amount|..."  — todas las pendientes

    Usado por: POST /api/prestamos/guardar-cuotas
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_guardar_cuotas_web]
    @company        VARCHAR(4),
    @person         VARCHAR(20),
    @loan_secuence  INT,
    @cuotas_text    VARCHAR(MAX),
    @xlastuser      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @loadamount     NUMERIC(19, 4),
        @loan_rate      NUMERIC(19, 4),
        @numberquotes   INT,
        @amountquote    NUMERIC(19, 4),
        @sum_all        NUMERIC(19, 4),
        @cnt_pending    INT,
        @cnt_edit       INT,
        @now            DATETIME,
        @work           VARCHAR(MAX),
        @part           VARCHAR(100),
        @pos            INT,
        @colon          INT,
        @sec_txt        VARCHAR(30),
        @amt_txt        VARCHAR(40),
        @sec_i          INT,
        @amt_n          NUMERIC(19, 4),
        @msg_suma       NVARCHAR(400);

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, 'web'))), 20);
    SET @now = GETDATE();
    SET @cuotas_text = LTRIM(RTRIM(ISNULL(@cuotas_text, '')));

    IF @company = '' OR @person = '' OR ISNULL(@loan_secuence, 0) <= 0
    BEGIN
        RAISERROR('Indique compañía, trabajador y préstamo.', 16, 1);
        RETURN;
    END;

    IF @cuotas_text = ''
    BEGIN
        RAISERROR('Indique los montos de las cuotas pendientes.', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID('tempdb..#cuotas_edit') IS NOT NULL DROP TABLE #cuotas_edit;
    CREATE TABLE #cuotas_edit (
        secuence INT NOT NULL PRIMARY KEY,
        amount   NUMERIC(19, 4) NOT NULL
    );

    SET @work = @cuotas_text + '|';
    WHILE LEN(@work) > 0
    BEGIN
        SET @pos = CHARINDEX('|', @work);
        IF @pos <= 0 BREAK;
        SET @part = LTRIM(RTRIM(SUBSTRING(@work, 1, @pos - 1)));
        SET @work = SUBSTRING(@work, @pos + 1, LEN(@work));
        IF @part = '' CONTINUE;

        SET @colon = CHARINDEX(':', @part);
        IF @colon <= 1
        BEGIN
            RAISERROR('Formato de cuotas inválido. Use secuence:monto|...', 16, 1);
            RETURN;
        END;

        SET @sec_txt = LTRIM(RTRIM(SUBSTRING(@part, 1, @colon - 1)));
        SET @amt_txt = LTRIM(RTRIM(SUBSTRING(@part, @colon + 1, LEN(@part))));

        SET @sec_i = NULL;
        SET @amt_n = NULL;
        IF @sec_txt <> '' AND @sec_txt NOT LIKE '%[^0-9]%'
            SET @sec_i = CONVERT(INT, @sec_txt);
        IF @amt_txt <> '' AND ISNUMERIC(@amt_txt) = 1
            SET @amt_n = ROUND(CONVERT(NUMERIC(19, 4), @amt_txt), 2);

        IF @sec_i IS NULL OR @amt_n IS NULL
        BEGIN
            RAISERROR('Formato de cuotas inválido. Use secuence:monto|...', 16, 1);
            RETURN;
        END;

        IF EXISTS (SELECT 1 FROM #cuotas_edit WHERE secuence = @sec_i)
        BEGIN
            RAISERROR('Hay cuotas duplicadas en el envío.', 16, 1);
            RETURN;
        END;

        INSERT INTO #cuotas_edit (secuence, amount) VALUES (@sec_i, @amt_n);
    END;

    IF EXISTS (SELECT 1 FROM #cuotas_edit WHERE amount <= 0)
    BEGIN
        RAISERROR('Cada cuota pendiente debe tener monto mayor a cero.', 16, 1);
        RETURN;
    END;

    SELECT
        @loadamount = ROUND(ISNULL(el.LoadAmount, 0), 2),
        @loan_rate = ISNULL(NULLIF(el.ExchangeRate, 0), 1)
    FROM PR_EmployeeLoan el WITH (UPDLOCK, HOLDLOCK)
    WHERE el.Company = @company
      AND el.Person = @person
      AND el.Secuence = @loan_secuence;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('El préstamo no existe.', 16, 1);
        RETURN;
    END;

    SELECT @cnt_pending = COUNT(*)
    FROM PR_EmployeeLoanAmortization ea WITH (UPDLOCK, HOLDLOCK)
    WHERE ea.Company = @company
      AND ea.Person = @person
      AND ea.LOANSECUENCE = @loan_secuence
      AND UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))) = 'P';

    SELECT @cnt_edit = COUNT(*) FROM #cuotas_edit;

    IF ISNULL(@cnt_pending, 0) = 0
    BEGIN
        RAISERROR('El préstamo no tiene cuotas pendientes para editar.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@cnt_edit, 0) <> ISNULL(@cnt_pending, 0)
    BEGIN
        RAISERROR('Debe enviar el monto de todas las cuotas pendientes del préstamo.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM #cuotas_edit e
        WHERE NOT EXISTS (
            SELECT 1
            FROM PR_EmployeeLoanAmortization ea
            WHERE ea.Company = @company
              AND ea.Person = @person
              AND ea.Secuence = e.secuence
              AND ea.LOANSECUENCE = @loan_secuence
              AND UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))) = 'P'
        )
    )
    BEGIN
        RAISERROR('Hay cuotas inválidas o que ya no están pendientes.', 16, 1);
        RETURN;
    END;

    SELECT @sum_all = ROUND(
        ISNULL((
            SELECT SUM(ISNULL(ea.Amount, 0))
            FROM PR_EmployeeLoanAmortization ea
            WHERE ea.Company = @company
              AND ea.Person = @person
              AND ea.LOANSECUENCE = @loan_secuence
              AND UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))) <> 'P'
        ), 0)
        + ISNULL((SELECT SUM(amount) FROM #cuotas_edit), 0)
    , 2);

    IF @sum_all <> @loadamount
    BEGIN
        SET @msg_suma =
            N'La suma de las cuotas ('
            + CONVERT(VARCHAR(30), @sum_all)
            + N') debe ser igual al importe del préstamo ('
            + CONVERT(VARCHAR(30), @loadamount)
            + N').';
        RAISERROR(@msg_suma, 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE ea
        SET
            Amount = e.amount,
            AmountLo = CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(ea.AmortizationCurrency, 'LO')))) = 'LO'
                    THEN e.amount
                ELSE ROUND(e.amount * ISNULL(NULLIF(ea.ExchangeRate, 0), @loan_rate), 2)
            END,
            AmountEx = CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(ea.AmortizationCurrency, 'LO')))) = 'LO'
                    THEN ROUND(e.amount / ISNULL(NULLIF(ea.ExchangeRate, 0), @loan_rate), 2)
                ELSE e.amount
            END,
            AMOUNTTOTAL = ROUND(e.amount + ISNULL(ea.INTEREST, 0), 2),
            AMOUNTTOTALLO = CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(ea.AmortizationCurrency, 'LO')))) = 'LO'
                    THEN e.amount
                ELSE ROUND(e.amount * ISNULL(NULLIF(ea.ExchangeRate, 0), @loan_rate), 2)
            END,
            AMOUNTTOTALEX = CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(ea.AmortizationCurrency, 'LO')))) = 'LO'
                    THEN ROUND(e.amount / ISNULL(NULLIF(ea.ExchangeRate, 0), @loan_rate), 2)
                ELSE e.amount
            END,
            XLastUser = @xlastuser,
            XLastDate = @now
        FROM PR_EmployeeLoanAmortization ea
        INNER JOIN #cuotas_edit e ON e.secuence = ea.Secuence
        WHERE ea.Company = @company
          AND ea.Person = @person
          AND ea.LOANSECUENCE = @loan_secuence
          AND UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))) = 'P';

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
            @loadamount AS loadamount,
            @amountquote AS amountquote,
            @sum_all AS suma_cuotas,
            @cnt_edit AS cuotas_actualizadas,
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
