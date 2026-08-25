/*
    Agrega una cuota pendiente a un préstamo que aún tiene amortizaciones pendientes.
    No modifica LoadAmount ni la cuenta corriente; el usuario redistribuye montos con
    sp_pr_prestamos_guardar_cuotas_web hasta que la suma = LoadAmount.

    Usado por: POST /api/prestamos/agregar-cuota
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_agregar_cuota_web]
    @company        VARCHAR(4),
    @person         VARCHAR(20),
    @loan_secuence  INT,
    @prperiod       VARCHAR(10),
    @amount         NUMERIC(19, 4),
    @xlastuser      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @loadamount       NUMERIC(19, 4),
        @loan_rate        NUMERIC(19, 4),
        @currency         VARCHAR(2),
        @costcenter       VARCHAR(20),
        @costcentercode   VARCHAR(20),
        @replicationunit  VARCHAR(4),
        @payrolltype      VARCHAR(20),
        @amortsecuence    INT,
        @amountlo         NUMERIC(19, 4),
        @amountex         NUMERIC(19, 4),
        @cnt_pending      INT,
        @numberquotes     INT,
        @amountquote      NUMERIC(19, 4),
        @sum_all          NUMERIC(19, 4),
        @now              DATETIME;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, 'web'))), 20);
    SET @prperiod = REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@prperiod, ''))), '-', ''), '/', '');
    SET @amount = ROUND(ISNULL(@amount, 0), 2);
    SET @now = GETDATE();

    IF @company = '' OR @person = '' OR ISNULL(@loan_secuence, 0) <= 0
    BEGIN
        RAISERROR('Indique compañía, trabajador y préstamo.', 16, 1);
        RETURN;
    END;

    IF LEN(@prperiod) < 8 OR ISNUMERIC(@prperiod) = 0
    BEGIN
        RAISERROR('Indique un periodo válido (YYYY-MM-DD).', 16, 1);
        RETURN;
    END;
    SET @prperiod = LEFT(@prperiod, 8);

    IF @amount <= 0
    BEGIN
        RAISERROR('El monto de la cuota debe ser mayor a cero.', 16, 1);
        RETURN;
    END;

    SELECT
        @loadamount = ROUND(ISNULL(el.LoadAmount, 0), 2),
        @loan_rate = ISNULL(NULLIF(el.ExchangeRate, 0), 1),
        @currency = UPPER(LTRIM(RTRIM(ISNULL(el.LoadCurrency, 'LO')))),
        @costcenter = LTRIM(RTRIM(el.CostCenter)),
        @costcentercode = LTRIM(RTRIM(el.CostCenterCode)),
        @replicationunit = LTRIM(RTRIM(el.ReplicationUnit))
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

    IF ISNULL(@cnt_pending, 0) = 0
    BEGIN
        RAISERROR('Solo se puede agregar cuotas mientras haya amortizaciones pendientes.', 16, 1);
        RETURN;
    END;

    SELECT @payrolltype = LTRIM(RTRIM(e.PayRollType))
    FROM PR_Employee e (NOLOCK)
    WHERE e.Company = @company
      AND e.Person = @person
      AND e.Status = 'N';

    IF @payrolltype IS NULL
    BEGIN
        RAISERROR('Trabajador no encontrado o inactivo.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Period pr (NOLOCK)
        WHERE pr.Company = @company
          AND pr.PayRollType = @payrolltype
          AND LTRIM(RTRIM(pr.PRPeriod)) = @prperiod
    )
    BEGIN
        RAISERROR('El periodo no existe en la planilla del trabajador.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeeLoanAmortization ea (NOLOCK)
        WHERE ea.Company = @company
          AND ea.Person = @person
          AND ea.LOANSECUENCE = @loan_secuence
          AND LTRIM(RTRIM(ea.PRperiod)) = @prperiod
    )
    BEGIN
        RAISERROR('Ya existe una cuota en ese periodo para este préstamo.', 16, 1);
        RETURN;
    END;

    IF @currency NOT IN ('LO', 'EX') SET @currency = 'LO';

    IF @currency = 'LO'
    BEGIN
        SET @amountlo = @amount;
        SET @amountex = ROUND(@amount / @loan_rate, 2);
    END
    ELSE
    BEGIN
        SET @amountlo = ROUND(@amount * @loan_rate, 2);
        SET @amountex = @amount;
    END;

    BEGIN TRY
        BEGIN TRAN;

        SELECT @amortsecuence = ISNULL(MAX(Secuence), 0)
        FROM PR_EmployeeLoanAmortization WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @company AND Person = @person;

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
            @person, @company, @amortsecuence, @prperiod,
            @currency, @loan_rate,
            @amount, @amountlo, @amountex,
            @costcenter, @costcentercode,
            'P', @replicationunit, @xlastuser, @now,
            @loan_secuence, 0, 0, 0,
            @amount, @amountlo, @amountex,
            'F', NULL
        );

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

        SELECT @sum_all = ROUND(ISNULL(SUM(ISNULL(Amount, 0)), 0), 2)
        FROM PR_EmployeeLoanAmortization
        WHERE Company = @company
          AND Person = @person
          AND LOANSECUENCE = @loan_secuence;

        COMMIT TRAN;

        SELECT
            @company AS company,
            @person AS person,
            @loan_secuence AS loan_secuence,
            @amortsecuence AS amort_secuence,
            @prperiod AS prperiod,
            @amount AS amount,
            @loadamount AS loadamount,
            @sum_all AS suma_cuotas,
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
