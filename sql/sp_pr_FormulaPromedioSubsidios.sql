/*
    Promedio de un concepto (FormulaCode) en el proceso actual, sobre los 12 periodos
    anteriores al periodo en cálculo (ACTUAL-12 .. ACTUAL-1).

    Ejemplo: periodo 20261010 → suma de oct-2025 a set-2026, divide entre 12;
    si el trabajador ingresó en ago-2026, divide entre 2 (ago + set).

    Usa f_getPromedioVac (Div. vacío = meses del rango desde ingreso/reingreso).

    Uso directo:
        DECLARE @r numeric(19,4);
        EXEC dbo.sp_pr_FormulaPromedioSubsidios
            @cia = 'BGT', @person = '12345678',
            @payrolltype = '...', @processtype = '...',
            @period = '20261010', @formulacode = 'TOTAL_REMU_AFP',
            @result = @r OUTPUT;

    Uso en fórmulas (vía sp_pr_formula_exec_proc_web):
        LET PROM = PROC("sp_pr_FormulaPromedioSubsidios", "TOTAL_REMU_AFP")
        RESULT = PROM
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_FormulaPromedioSubsidios
    @cia         varchar(20),
    @person      varchar(20),
    @payrolltype varchar(20),
    @processtype varchar(20),
    @period      varchar(20),
    @formulacode varchar(50),
    @result      numeric(19, 4) OUTPUT
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

    IF @cia = '' OR @person = '' OR @payrolltype = '' OR @processtype = ''
       OR @period = '' OR @formulacode = ''
        RETURN;

    DECLARE @concept varchar(20) = NULL;
    SELECT TOP 1 @concept = Concept
    FROM dbo.PR_Concept (NOLOCK)
    WHERE Company = @cia
      AND UPPER(LTRIM(RTRIM(ISNULL(FormulaCode, '')))) = @formulacode
    ORDER BY Concept;

    IF ISNULL(@concept, '') = ''
        RETURN;

    DECLARE @ord int = NULL;
    SELECT @ord = PeriodOrder
    FROM dbo.PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND PRPeriod = @period;

    IF @ord IS NULL
        RETURN;

    DECLARE @period_begin varchar(20) = NULL;
    DECLARE @period_end   varchar(20) = NULL;

    SELECT @period_begin = PRPeriod
    FROM dbo.PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND PeriodOrder = @ord - 12;

    SELECT @period_end = PRPeriod
    FROM dbo.PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND PeriodOrder = @ord - 1;

    IF @period_begin IS NULL OR @period_end IS NULL
        RETURN;

    DECLARE @fechaingreso datetime = NULL;
    SELECT TOP 1 @fechaingreso = ISNULL(E.ReEntryDate, E.EntryDate)
    FROM dbo.PR_Employee E (NOLOCK)
    WHERE E.Company = @cia
      AND E.Person = @person
      AND E.PayRollType = @payrolltype;

    IF OBJECT_ID('dbo.f_getPromedioVac', 'FN') IS NULL
        RETURN;

    SET @result = ISNULL(dbo.f_getPromedioVac(
        @cia,
        @person,
        @payrolltype,
        @processtype,
        @period_begin,
        @period_end,
        @concept,
        0,          /* sin mínimo de meses con importe > 0 */
        NULL,       /* Div. vacío: meses del rango desde ingreso */
        @fechaingreso
    ), 0);
END
GO
