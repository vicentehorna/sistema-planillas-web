/*
    Ausencias del semestre de pago de CTS.

    El periodo de cálculo es el del pago (mayo o noviembre). Devuelve en @dias la suma de:
        f_getDiasFalta (CANT_DIAS_AUSENCIA)
      + f_getDiasLSG (licencia sin goce)
      + f_getDiasSUSP (suspensión)
    sobre el proceso FIN_DE_MES del semestre:
      - Noviembre -> 1 de mayo a 31 de octubre del mismo año
      - Mayo      -> 1 de noviembre del año anterior a 30 de abril
    Si el ingreso o reingreso cae dentro del semestre, esa fecha es el inicio.
    Otro mes, o alta posterior al fin del semestre, devuelve 0.

    Uso directo:
        DECLARE @d numeric(19,4);
        EXEC dbo.sp_pr_obtenerAusenciasPagoCTS @cia = 'BGT', @person = '71230705', @period = '20261111', @dias = @d OUTPUT;

    Uso en fórmulas (vía sp_pr_formula_exec_proc_web, pasa el trabajador y periodo en cálculo):
        LET AUSENCIAS = PROC("sp_pr_obtenerAusenciasPagoCTS")
        RESULT =
        IF AUSENCIAS > 0 THEN
          AUSENCIAS
        ELSE
          0
        END
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_obtenerAusenciasPagoCTS
    @cia varchar(20),
    @person varchar(20),
    @period varchar(20),
    @dias numeric(19, 4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @dias = 0;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    IF @cia = '' OR @person = '' OR LEN(@period) < 6
        RETURN;

    IF LEFT(@period, 6) LIKE '%[^0-9]%'
        RETURN;

    DECLARE @mes int;
    DECLARE @anio int;
    DECLARE @ini date;
    DECLARE @fin date;
    DECLARE @fechaingreso datetime;

    SET @mes = CONVERT(int, SUBSTRING(@period, 5, 2));
    SET @anio = CONVERT(int, LEFT(@period, 4));

    IF @mes = 11
    BEGIN
        SET @ini = CONVERT(date, CONVERT(char(4), @anio) + '0501');
        SET @fin = CONVERT(date, CONVERT(char(4), @anio) + '1031');
    END
    ELSE IF @mes = 5
    BEGIN
        SET @ini = CONVERT(date, CONVERT(char(4), @anio - 1) + '1101');
        SET @fin = CONVERT(date, CONVERT(char(4), @anio) + '0430');
    END
    ELSE
        RETURN;

    SELECT @fechaingreso = ISNULL(e.ReEntryDate, e.EntryDate)
    FROM dbo.PR_Employee e (NOLOCK)
    WHERE e.Company = @cia
      AND e.Person = @person;

    IF @fechaingreso IS NOT NULL AND CONVERT(date, @fechaingreso) > @ini
        SET @ini = CONVERT(date, @fechaingreso);

    IF @ini > @fin
        RETURN;

    SET @dias = ISNULL(dbo.f_getDiasFalta(@ini, @fin, @cia, @person), 0)
              + ISNULL(dbo.f_getDiasLSG(@ini, @fin, @cia, @person), 0)
              + ISNULL(dbo.f_getDiasSUSP(@ini, @fin, @cia, @person), 0);
END
GO
