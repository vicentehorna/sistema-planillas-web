/*
    Control de Datos CTS — por trabajador (migración de ControlDatosCTS de PowerBuilder).

    Pasa el resultado del cálculo del proceso Pago de CTS (PR_EmployeePayRollConcept)
    a PR_EmployeeCTS (cabecera) y PR_EmployeeCTSConcept (remuneración computable).
    Se ejecuta antes de generar el Formato de CTS de cada trabajador; es re-ejecutable
    (borra y vuelve a insertar los datos de la persona).

    PR_CTSPeriod es interno: si no existe el periodo de CTS para el tipo de planilla y
    periodo de cálculo, se crea el siguiente correlativo (CTSNumber es único en toda la
    tabla, no por tipo de planilla). Solo periodos de mayo (yyyy05..) y noviembre (yyyy11..):
      mayo      → 01/11 del año anterior al 30/04, pago 15/05
      noviembre → 01/05 al 31/10, pago 15/11

    No usa la provisión (PR_CTSProvision / PR_CTSProvisionTxn) ni el interés (queda en 0).

    Configuración en PR_Mapping: CTSConcept, CTSYearsConcept, CTSMonthsConcept,
    CTSDaysConcept, CTSRemSet (PR_ConceptSetDetail), CTSProcessType.

    Usado por: generar_pdf_formato_cts (app.py)

    Retorna: ctsnumber, generado (1 = tiene concepto CTS y se grabó), amount
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_control_datos_cts_persona]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20),
    @userid      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @userid = LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@userid)), ''), 'WEB'), 20);

    IF @cia = '' OR @payrolltype = '' OR @period = '' OR @person = ''
    BEGIN
        RAISERROR('Faltan parámetros para el control de datos de CTS.', 16, 1);
        RETURN;
    END

    DECLARE @concept VARCHAR(20), @yearsconcept VARCHAR(20), @monthsconcept VARCHAR(20),
            @daysconcept VARCHAR(20), @remset VARCHAR(20), @processtype VARCHAR(20);

    SELECT TOP 1
        @concept = CTSConcept,
        @yearsconcept = CTSYearsConcept,
        @monthsconcept = CTSMonthsConcept,
        @daysconcept = CTSDaysConcept,
        @remset = CTSRemSet,
        @processtype = CTSProcessType
    FROM PR_Mapping
    WHERE Company = @cia;

    IF @concept IS NULL OR @yearsconcept IS NULL OR @monthsconcept IS NULL
       OR @daysconcept IS NULL OR @remset IS NULL OR @processtype IS NULL
    BEGIN
        RAISERROR('Debe configurarse los conceptos de CTS de la compañía (PR_Mapping).', 16, 1);
        RETURN;
    END

    DECLARE @anio INT, @mes VARCHAR(2);
    SET @mes = SUBSTRING(@period, 5, 2);
    IF LEN(@period) < 6 OR ISNUMERIC(LEFT(@period, 4)) = 0 OR @mes NOT IN ('05', '11')
    BEGIN
        RAISERROR('El periodo %s no es un periodo de CTS (solo mayo o noviembre).', 16, 1, @period);
        RETURN;
    END
    SET @anio = CAST(LEFT(@period, 4) AS INT);

    IF NOT EXISTS (SELECT 1 FROM PR_Period WHERE PayRollType = @payrolltype AND PRPeriod = @period)
    BEGIN
        RAISERROR('El periodo %s no existe para el tipo de planilla.', 16, 1, @period);
        RETURN;
    END

    DECLARE @datebegin DATETIME, @dateend DATETIME, @paymentdate DATETIME;
    IF @mes = '05'
    BEGIN
        SET @datebegin = DATEADD(MONTH, 10, DATEADD(YEAR, @anio - 1 - 1900, 0));
        SET @dateend = DATEADD(DAY, 29, DATEADD(MONTH, 3, DATEADD(YEAR, @anio - 1900, 0)));
        SET @paymentdate = DATEADD(DAY, 14, DATEADD(MONTH, 4, DATEADD(YEAR, @anio - 1900, 0)));
    END
    ELSE
    BEGIN
        SET @datebegin = DATEADD(MONTH, 4, DATEADD(YEAR, @anio - 1900, 0));
        SET @dateend = DATEADD(DAY, 30, DATEADD(MONTH, 9, DATEADD(YEAR, @anio - 1900, 0)));
        SET @paymentdate = DATEADD(DAY, 14, DATEADD(MONTH, 10, DATEADD(YEAR, @anio - 1900, 0)));
    END

    DECLARE @repunit VARCHAR(4);
    SELECT @repunit = LEFT(ReplicationUnit, 4) FROM SY_Company WHERE Company = @cia;

    DECLARE @ctsnumber INT, @generado BIT = 0, @amount NUMERIC(18, 4) = NULL;
    DECLARE @now DATETIME = GETDATE();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @ctsnumber = CTSNumber
        FROM PR_CTSPeriod WITH (UPDLOCK, HOLDLOCK)
        WHERE PayRollType = @payrolltype
          AND PRPeriod = @period;

        IF @ctsnumber IS NULL
        BEGIN
            SELECT @ctsnumber = ISNULL(MAX(CTSNumber), 0) + 1
            FROM PR_CTSPeriod WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO PR_CTSPeriod
                (CTSNumber, PayRollType, PRPeriod, DateBegin, DateEnd, PaymentDate, Status,
                 Company, ReplicationUnit, XLastUser, XLastDate)
            VALUES
                (@ctsnumber, @payrolltype, @period, @datebegin, @dateend, @paymentdate, 'P',
                 @cia, @repunit, @userid, @now);
        END

        DELETE FROM PR_EmployeeCTSConcept
        WHERE Company = @cia
          AND PayRollType = @payrolltype
          AND CTSNumber = @ctsnumber
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_EmployeeCTS
        WHERE Company = @cia
          AND PayRollType = @payrolltype
          AND CTSNumber = @ctsnumber
          AND PRPeriod = @period
          AND Person = @person;

        IF EXISTS (
            SELECT 1
            FROM PR_EmployeePayRollConcept
            WHERE Company = @cia
              AND PayRollType = @payrolltype
              AND ProcessType = @processtype
              AND PRPeriod = @period
              AND Person = @person
              AND Concept = @concept
        )
        BEGIN
            INSERT INTO PR_EmployeeCTS
                (CTSNumber, PayRollType, PRPeriod, Person, Company,
                 Bank, AccountType, BankCurrency, BankNumber,
                 Years, Months, Days,
                 Amount, AmountLo, AmountEx, AmountCurrency, ExchangeRate,
                 PorcInterest, DaysInterest, AmountInterest, AmountInterestLo, AmountInterestEx,
                 ReplicationUnit, XLastUser, XLastDate)
            SELECT
                @ctsnumber, @payrolltype, @period, @person, @cia,
                E.CTSBank, E.CTSAccountType, E.CTSCurrency, E.CTSAccount,
                (SELECT CAST(ROUND(Y.ConceptValue, 0) AS INT)
                   FROM PR_EmployeePayRollConcept Y
                  WHERE Y.Company = @cia AND Y.PayRollType = @payrolltype AND Y.ProcessType = @processtype
                    AND Y.PRPeriod = @period AND Y.Person = @person AND Y.Concept = @yearsconcept),
                (SELECT CAST(ROUND(M.ConceptValue, 0) AS INT)
                   FROM PR_EmployeePayRollConcept M
                  WHERE M.Company = @cia AND M.PayRollType = @payrolltype AND M.ProcessType = @processtype
                    AND M.PRPeriod = @period AND M.Person = @person AND M.Concept = @monthsconcept),
                (SELECT CAST(ROUND(D.ConceptValue, 0) AS INT)
                   FROM PR_EmployeePayRollConcept D
                  WHERE D.Company = @cia AND D.PayRollType = @payrolltype AND D.ProcessType = @processtype
                    AND D.PRPeriod = @period AND D.Person = @person AND D.Concept = @daysconcept),
                ROUND(C.ConceptValue, 2), ROUND(C.ConceptValueLo, 2), ROUND(C.ConceptValueEx, 2),
                C.ConceptCurrency, C.ExchangeRate,
                0, 0, 0, 0, 0,
                @repunit, @userid, @now
            FROM PR_EmployeePayRollConcept C
                LEFT JOIN PR_Employee E
                    ON E.Company = C.Company
                   AND E.Person = C.Person
            WHERE C.Company = @cia
              AND C.PayRollType = @payrolltype
              AND C.ProcessType = @processtype
              AND C.PRPeriod = @period
              AND C.Person = @person
              AND C.Concept = @concept;

            INSERT INTO PR_EmployeeCTSConcept
                (Concept, CTSNumber, PayRollType, PRPeriod, Person, Company,
                 ConceptCurrency, ExchangeRate, ConceptValue, ConceptValueLo, ConceptValueEx,
                 ReplicationUnit, XLastUser, XLastDate)
            SELECT
                C.Concept, @ctsnumber, @payrolltype, @period, @person, @cia,
                C.ConceptCurrency, C.ExchangeRate,
                ROUND(C.ConceptValue, 2), ROUND(C.ConceptValueLo, 2), ROUND(C.ConceptValueEx, 2),
                @repunit, @userid, @now
            FROM PR_EmployeePayRollConcept C
            WHERE C.Company = @cia
              AND C.PayRollType = @payrolltype
              AND C.ProcessType = @processtype
              AND C.PRPeriod = @period
              AND C.Person = @person
              AND C.Concept IN (
                    SELECT S.Concept
                    FROM PR_ConceptSetDetail S
                    WHERE S.ConceptSet = @remset
              );

            SELECT @amount = Amount
            FROM PR_EmployeeCTS
            WHERE Company = @cia
              AND PayRollType = @payrolltype
              AND CTSNumber = @ctsnumber
              AND PRPeriod = @period
              AND Person = @person;

            SET @generado = 1;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE();
        RAISERROR('Control de datos CTS (%s): %s', 16, 1, @person, @msg);
        RETURN;
    END CATCH

    SELECT @ctsnumber AS ctsnumber, @generado AS generado, @amount AS amount;
END
GO
