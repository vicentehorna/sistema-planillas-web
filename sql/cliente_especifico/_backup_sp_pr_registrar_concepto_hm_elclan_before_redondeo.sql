-- ============================================================================
-- [172/292] sp_pr_registrar_concepto.sql
-- ============================================================================

/*
    Registra un concepto calculado en PR_EmployeePayRollConcept.
    Mejora: valida FormulaCode y da error claro si no existe; fallback trim/case.
*/
CREATE   PROCEDURE [dbo].[sp_pr_registrar_concepto]
    @company varchar(4),
    @payrolltype varchar(20),
    @processtype varchar(20),
    @period varchar(20),
    @person varchar(20),
    @UserID varchar(20),
    @tc numeric(19,4),
    @formulacode varchar(255),
    @importe numeric(19,4),
    @flagmonetario char(1)
AS
BEGIN
    SET NOCOUNT ON;

    SET @importe = ROUND(@importe, 4);

    DECLARE @concept varchar(20);

    SELECT @concept = Concept
    FROM PR_Concept
    WHERE Company = @company
      AND FormulaCode = @formulacode;

    IF @concept IS NULL
    BEGIN
        SELECT TOP 1 @concept = Concept
        FROM PR_Concept
        WHERE Company = @company
          AND UPPER(LTRIM(RTRIM(FormulaCode))) = UPPER(LTRIM(RTRIM(ISNULL(@formulacode, ''))));
    END

    IF @concept IS NULL
    BEGIN
        DECLARE @msg varchar(500);
        SET @msg = 'Concepto no existe FormulaCode=[' + ISNULL(@formulacode, 'NULL')
                 + '] cia=' + ISNULL(@company, '');
        RAISERROR(@msg, 16, 1);
        RETURN;
    END

    INSERT INTO PR_EmployeePayRollConcept (
        Concept, Person, Company, ProcessType, PayRollType, PRPeriod,
        ConceptValue, FlagIsMonetary, ConceptCurrency, ConceptValueLo, ConceptValueEx,
        ExchangeRate, ReplicationUnit, XLastUser, XLastDate, flagPayment
    )
    SELECT
        @concept,
        PR_Employee.Person,
        PR_Employee.Company,
        @processtype,
        PR_Employee.PayRollType,
        @period,
        @importe,
        @flagmonetario,
        'LO',
        @importe,
        CASE
            WHEN @flagmonetario = 'Y' AND ISNULL(@tc, 0) <> 0
                THEN ROUND(@importe / (@tc * 1.0000), 2)
            ELSE NULL
        END,
        CASE
            WHEN @flagmonetario = 'Y' AND ISNULL(@tc, 0) <> 0 THEN @tc
            ELSE NULL
        END,
        SY_Person.ReplicationUnit,
        @UserID,
        GETDATE(),
        'N'
    FROM PR_Employee
    INNER JOIN SY_Person ON PR_Employee.Person = SY_Person.Person
    WHERE PR_Employee.Person = @person
      AND PR_Employee.Company = @company;
END