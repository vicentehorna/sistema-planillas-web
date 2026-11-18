/*
    Ausencias del semestre de pago de GRATIFICACIÓN.

    El periodo de cálculo es el del pago (julio o diciembre). Devuelve en @dias la suma de:
        f_getDiasFalta (CANT_DIAS_AUSENCIA)
      + f_getDiasLSG (licencia sin goce)
      + f_getDiasSUSP (suspensión)
      + f_getDiasPorFuera (DIAS_POR_FUERA)
    sobre el proceso FIN_DE_MES del semestre:
      - Julio     -> 1 de enero a 30 de junio del mismo año
      - Diciembre -> 1 de julio a 31 de diciembre del mismo año
    Si el ingreso o reingreso cae dentro del semestre, esa fecha es el inicio.
    Otro mes, o alta posterior al fin del semestre, devuelve 0.

    Uso directo:
        DECLARE @d numeric(19,4);
        EXEC dbo.sp_pr_obtenerAusenciasGratificacion @cia = 'BGT', @person = '71230705', @period = '20260707', @dias = @d OUTPUT;

    Uso en fórmulas (vía sp_pr_formula_exec_proc_web, pasa el trabajador y periodo en cálculo):
        LET AUSENCIAS = PROC("sp_pr_obtenerAusenciasGratificacion")
        RESULT =
        IF AUSENCIAS > 0 THEN
          AUSENCIAS
        ELSE
          0
        END
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_obtenerAusenciasGratificacion
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

    IF @mes = 7
    BEGIN
        SET @ini = CONVERT(date, CONVERT(char(4), @anio) + '0101');
        SET @fin = CONVERT(date, CONVERT(char(4), @anio) + '0630');
    END
    ELSE IF @mes = 12
    BEGIN
        SET @ini = CONVERT(date, CONVERT(char(4), @anio) + '0701');
        SET @fin = CONVERT(date, CONVERT(char(4), @anio) + '1231');
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
              + ISNULL(dbo.f_getDiasSUSP(@ini, @fin, @cia, @person), 0)
              + ISNULL(dbo.f_getDiasPorFuera(@ini, @fin, @cia, @person), 0);
END
GO
