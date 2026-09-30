/*
    Devuelve las horas del periodo registradas en Tablas > Horas Trabajadas
    (dbo.PR_HorasTrabajadas, compañía principal BGT). Solo hm_garc.

    @period acepta YYYYMM o YYYYMMDD (PR_Period, p.ej. 20260909); se compara por año-mes.
    Si el periodo no está registrado devuelve 0.

    Si se indica @person, prorratea según ingreso (ISNULL(ReEntryDate, EntryDate)) y cese (CeaseDate)
    cuando alguno cae dentro del mes, sobre mes comercial de 30 días:
        ingreso día 17           -> días = 30 - 17 + 1 = 14 -> ROUND(14 * horas / 30, 0)
        cese día 17              -> días = 17
        ingreso y cese en el mes -> días = cese - ingreso + 1
    El cese en el último día del mes (o día 31) cuenta como día 30; ingreso el día 1 = mes completo.
    Ingreso posterior al mes o cese anterior al mes -> 0.

    Uso directo:
        DECLARE @h numeric(19,4);
        EXEC dbo.sp_pr_obtenerhorastrabajadas @period = '20260909', @horas = @h OUTPUT,
             @cia = 'S445', @payrolltype = 'S445000000000004', @person = '72092029';

    Uso en fórmulas (vía sp_pr_formula_exec_proc_web, pasa el trabajador en cálculo):
        LET HORAS = PROC("sp_pr_obtenerhorastrabajadas")
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_obtenerhorastrabajadas
    @period varchar(20),
    @horas numeric(19, 4) OUTPUT,
    @cia varchar(20) = NULL,
    @payrolltype varchar(20) = NULL,
    @person varchar(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @horas = 0;

    DECLARE @p varchar(20) = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@period, ''))), '-', ''), '/', ''), ' ', '');
    IF LEN(@p) < 6 OR @p LIKE '%[^0-9]%'
        RETURN;

    DECLARE @horas_mes numeric(19, 4) = NULL;

    SELECT TOP 1 @horas_mes = CAST(NroHoras AS numeric(19, 4))
    FROM dbo.PR_HorasTrabajadas
    WHERE Company = 'BGT'
      AND LEFT(Period, 6) = LEFT(@p, 6)
    ORDER BY Period;

    IF ISNULL(@horas_mes, 0) <= 0
        RETURN;

    SET @person = NULLIF(LTRIM(RTRIM(ISNULL(@person, ''))), '');
    IF @person IS NULL
    BEGIN
        SET @horas = @horas_mes;
        RETURN;
    END

    DECLARE @inicio_mes date = CONVERT(date, LEFT(@p, 6) + '01', 112);
    DECLARE @fin_mes date = EOMONTH(@inicio_mes);
    DECLARE @ingreso date = NULL;
    DECLARE @cese date = NULL;

    SELECT TOP 1
        @ingreso = CONVERT(date, ISNULL(E.ReEntryDate, E.EntryDate)),
        @cese = CONVERT(date, E.CeaseDate)
    FROM dbo.PR_Employee E (NOLOCK)
    WHERE E.Person = @person
      AND (NULLIF(LTRIM(RTRIM(ISNULL(@cia, ''))), '') IS NULL OR E.Company = @cia)
    ORDER BY
        CASE WHEN E.PayRollType = @payrolltype THEN 0 ELSE 1 END,
        ISNULL(E.ReEntryDate, E.EntryDate) DESC;

    IF @cese IS NOT NULL AND @ingreso IS NOT NULL AND @cese < @ingreso
        SET @cese = NULL;

    IF (@ingreso IS NOT NULL AND @ingreso > @fin_mes)
       OR (@cese IS NOT NULL AND @cese < @inicio_mes)
        RETURN;

    DECLARE @dia_ini int = 1;
    DECLARE @dia_fin int = 30;

    IF @ingreso IS NOT NULL AND @ingreso >= @inicio_mes
        SET @dia_ini = CASE WHEN DAY(@ingreso) > 30 THEN 30 ELSE DAY(@ingreso) END;

    IF @cese IS NOT NULL AND @cese <= @fin_mes
        SET @dia_fin = CASE WHEN @cese = @fin_mes OR DAY(@cese) > 30 THEN 30 ELSE DAY(@cese) END;

    DECLARE @dias int = @dia_fin - @dia_ini + 1;

    IF @dias >= 30
        SET @horas = @horas_mes;
    ELSE IF @dias > 0
        SET @horas = ROUND(@dias * @horas_mes / 30.0, 0);
END
GO
