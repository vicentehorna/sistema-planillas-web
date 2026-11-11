/*
    Promedio CTS de un concepto (FormulaCode) vía formulador PROC().

    Igual que el tipo U (f_getPromedioCts): el periodo inicial lo fija el ciclo CTS
    según el periodo FIN:
      - Fin may–oct → inicio mayo (mismo año)
      - Fin nov–abr → inicio noviembre (año anterior si ene–abr)

    Periodo FIN:
      - Proceso CTS  → ACTUAL - 1 (p.ej. pago nov → oct → rango may–oct)
      - Otros (p.ej. LIQUIDACION) → ACTUAL (como NumberFIN vacío en elclan)

    Importes: siempre desde FIN_DE_MES (igual que las líneas tipo U de elclan).

    @valor_minimo:
      Meses del rango (desde ingreso/reingreso) con importe > 0 exigidos. Si hay menos → 0.
      Ej.: 3 = mismo criterio típico de elclan tipo U.
      Reingreso: solo cuentan meses >= ReEntryDate (p.ej. reingreso sep → oct = 2 < 3 → 0).

    @divisor:
      > 0 → divide siempre entre ese valor (p.ej. 6), aunque haya ingresado hace 2 meses.
      NULL o 0 → divide entre meses del rango desde ingreso/reingreso.
      En ambos casos la suma solo incluye meses desde ingreso/reingreso.

    Uso directo:
        DECLARE @r numeric(19,4);
        EXEC dbo.sp_pr_FormulaPromedioCTS
            @cia = 'BGT', @person = '12345678',
            @payrolltype = '...', @processtype = '...',
            @period = '20261111', @formulacode = 'COMISION',
            @valor_minimo = 3, @divisor = 6, @result = @r OUTPUT;

    Uso en fórmulas (vía sp_pr_formula_exec_proc_web):
        LET PROM = PROC("sp_pr_FormulaPromedioCTS", "COMISION", 3, 6)
        LET PROM2 = PROC("sp_pr_FormulaPromedioCTS", "COMISION", 3)
        LET PROM3 = PROC("sp_pr_FormulaPromedioCTS", "COMISION")
        RESULT = PROM
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_FormulaPromedioCTS
    @cia           varchar(20),
    @person        varchar(20),
    @payrolltype   varchar(20),
    @processtype   varchar(20),
    @period        varchar(20),
    @formulacode   varchar(50),
    @valor_minimo  numeric(19, 4) = 0,
    @divisor       numeric(19, 4) = NULL,
    @result        numeric(19, 4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @result = 0;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @formulacode = UPPER(LTRIM(RTRIM(ISNULL(@formulacode, ''))));
    SET @valor_minimo = ISNULL(@valor_minimo, 0);
    IF ISNULL(@divisor, 0) <= 0
        SET @divisor = NULL;

    IF @cia = '' OR @person = '' OR @payrolltype = '' OR @processtype = ''
       OR @period = '' OR @formulacode = ''
        RETURN;

    IF OBJECT_ID('dbo.f_getPromedioCts', 'FN') IS NULL
        RETURN;

    DECLARE @concept varchar(20) = NULL;
    SELECT TOP 1 @concept = Concept
    FROM dbo.PR_Concept (NOLOCK)
    WHERE Company = @cia
      AND UPPER(LTRIM(RTRIM(ISNULL(FormulaCode, '')))) = @formulacode
    ORDER BY Concept;

    IF ISNULL(@concept, '') = ''
        RETURN;

    /* Importes mensuales del concepto: proceso FIN_DE_MES */
    DECLARE @process_finmes varchar(20) = NULL;
    SELECT TOP 1 @process_finmes = ProcessType
    FROM dbo.PR_ProcessType (NOLOCK)
    WHERE Company = @cia
      AND ShortName = 'FIN_DE_MES'
    ORDER BY ProcessType;

    IF ISNULL(@process_finmes, '') = ''
        SET @process_finmes = @processtype;

    DECLARE @proc_short varchar(50) = NULL;
    SELECT TOP 1 @proc_short = UPPER(LTRIM(RTRIM(ISNULL(ShortName, ''))))
    FROM dbo.PR_ProcessType (NOLOCK)
    WHERE Company = @cia
      AND ProcessType = @processtype;

    DECLARE @ord int = NULL;
    SELECT @ord = PeriodOrder
    FROM dbo.PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND PRPeriod = @period;

    IF @ord IS NULL
        RETURN;

    /* CTS: fin = periodo anterior; liquidación/otros: fin = periodo actual */
    DECLARE @ord_fin int =
        CASE WHEN @proc_short = 'CTS' THEN @ord - 1 ELSE @ord END;

    DECLARE @period_end varchar(20) = NULL;
    SELECT @period_end = PRPeriod
    FROM dbo.PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND PeriodOrder = @ord_fin;

    IF @period_end IS NULL
        RETURN;

    DECLARE @fechaingreso datetime = NULL;
    SELECT TOP 1 @fechaingreso = ISNULL(E.ReEntryDate, E.EntryDate)
    FROM dbo.PR_Employee E (NOLOCK)
    WHERE E.Company = @cia
      AND E.Person = @person
      AND E.PayRollType = @payrolltype;

    SET @result = ISNULL(dbo.f_getPromedioCts(
        @cia,
        @person,
        @payrolltype,
        @process_finmes,
        @period,
        @period_end,
        @concept,
        @valor_minimo,
        @divisor,
        @fechaingreso
    ), 0);
END
GO
