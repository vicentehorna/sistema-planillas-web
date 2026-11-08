/*
    Detalle de CTS por trabajador (semestre computable).
    Usado por: POST /api/reportes/detalle-cts (reporte_detalle_cts.html).

    Requiere PAGO DE CTS calculado en el periodo (PR_ProcessType.ShortName = 'CTS').
    Solo periodos de mayo (05) o noviembre (11).

    Filas:
      - Noviembre YYYY: meses Mayo..Octubre del mismo año (desc: Oct→May)
      - Mayo YYYY: meses Noviembre(YYYY-1)..Abril(YYYY) (desc: Abr→Nov)

    Columnas CTS: horas extras, bono, feriado, comisión, ausencias
    (CANT_DIAS_AUSENCIA + DIASLICSGOCE + DIASUSPENSION).

    Usa: f_getSumaConceptoPromedio, f_getMesesDividir.
*/
CREATE OR ALTER PROCEDURE [dbo].[SP_PR_ReporteDetalleCTS]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20),
    @period       VARCHAR(20),
    @person       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fechaingreso DATETIME;
    DECLARE @ceasedate    DATETIME;
    DECLARE @extras       VARCHAR(50) = 'C_HORASEXTRAS';
    DECLARE @bono         VARCHAR(50) = 'SOBRETASA_NOCHE';
    DECLARE @feriado      VARCHAR(50) = 'FERIADOS';
    DECLARE @comision     VARCHAR(50) = 'COMISION';
    DECLARE @faltas       VARCHAR(50) = 'CANT_DIAS_AUSENCIA';
    DECLARE @lsg          VARCHAR(50) = 'DIASLICSGOCE';
    DECLARE @susp         VARCHAR(50) = 'DIASUSPENSION';
    DECLARE @mes          INT = 0;
    DECLARE @yyyy         INT;
    DECLARE @mm           INT;
    DECLARE @fechaIniSem  DATE;
    DECLARE @fechaFinSem  DATE;
    DECLARE @fechaIniCalc DATE;
    DECLARE @fechaFinCalc DATE;
    DECLARE @basePeriod   DATETIME;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    IF LEN(@period) < 6
        RETURN;

    SET @yyyy = CONVERT(INT, LEFT(@period, 4));
    SET @mm = CONVERT(INT, SUBSTRING(@period, 5, 2));

    IF @mm NOT IN (5, 11)
        RETURN;

    /* Semestre computable según mes de pago CTS. */
    IF @mm = 11
    BEGIN
        SET @fechaIniSem = CONVERT(DATE, CONVERT(CHAR(4), @yyyy) + '0501');
        SET @fechaFinSem = CONVERT(DATE, CONVERT(CHAR(4), @yyyy) + '1031');
    END
    ELSE
    BEGIN
        SET @fechaIniSem = CONVERT(DATE, CONVERT(CHAR(4), @yyyy - 1) + '1101');
        SET @fechaFinSem = CONVERT(DATE, CONVERT(CHAR(4), @yyyy) + '0430');
    END;

    /* Ancla: primer día del mes del periodo CTS (para DATEADD de filas). */
    SET @basePeriod = CONVERT(DATETIME, LEFT(@period, 6) + '01');

    CREATE TABLE #temp_reporte (
        periodo      VARCHAR(20),
        he_cts       NUMERIC(19, 4),
        bono_cts     NUMERIC(19, 4),
        feriado_cts  NUMERIC(19, 4),
        comision_cts NUMERIC(19, 4),
        faltas_cts   NUMERIC(19, 4),
        person       VARCHAR(20)
    );

    /* Datos del trabajador en PAGO DE CTS del periodo. */
    SELECT
        @fechaingreso = COALESCE(ep.EntryDate, e.EntryDate),
        @ceasedate = COALESCE(ep.CeaseDate, e.CeaseDate)
    FROM PR_EmployeePayRoll ep
    LEFT JOIN PR_Employee e
        ON e.Person = ep.Person AND e.Company = ep.Company
    WHERE ep.Company = @cia
      AND ep.PRPeriod = @period
      AND ep.Person = @person
      AND ep.PayRollType = @payrolltype
      AND EXISTS (
            SELECT 1
            FROM PR_ProcessType pt
            WHERE pt.ProcessType = ep.ProcessType
              AND pt.Company = ep.Company
              AND UPPER(LTRIM(RTRIM(pt.ShortName))) = 'CTS'
      );

    IF @fechaingreso IS NULL
    BEGIN
        /* Fallback: maestro empleado si aún no hay cabecera CTS. */
        SELECT
            @fechaingreso = EntryDate,
            @ceasedate = CeaseDate
        FROM PR_Employee
        WHERE Company = @cia AND Person = @person;
    END;

    IF @fechaingreso IS NULL
        RETURN;

    SET @fechaIniCalc = CASE
        WHEN CONVERT(DATE, @fechaingreso) > @fechaIniSem THEN CONVERT(DATE, @fechaingreso)
        ELSE @fechaIniSem
    END;

    SET @fechaFinCalc = CASE
        WHEN @ceasedate IS NOT NULL AND CONVERT(DATE, @ceasedate) < @fechaFinSem
            THEN CONVERT(DATE, @ceasedate)
        ELSE @fechaFinSem
    END;

    IF @fechaIniCalc > @fechaFinCalc
        RETURN;

    /*
      Filas: 6 meses previos al mes de pago CTS.
      Nov -> Oct..May; May -> Abr..Nov(año ant).
    */
    WHILE @mes <= 5
    BEGIN
        INSERT INTO #temp_reporte (periodo, he_cts, bono_cts, feriado_cts, comision_cts, faltas_cts, person)
        VALUES (
            CONVERT(VARCHAR(6), DATEADD(MONTH, -1 - @mes, @basePeriod), 112)
                + RIGHT(CONVERT(VARCHAR(6), DATEADD(MONTH, -1 - @mes, @basePeriod), 112), 2),
            0, 0, 0, 0, 0,
            @person
        );
        SET @mes = @mes + 1;
    END;

    UPDATE #temp_reporte
    SET
        he_cts = dbo.f_getSumaConceptoPromedio(@fechaIniCalc, @fechaFinCalc, @cia, @person, @extras, periodo),
        bono_cts = dbo.f_getSumaConceptoPromedio(@fechaIniCalc, @fechaFinCalc, @cia, @person, @bono, periodo),
        feriado_cts = dbo.f_getSumaConceptoPromedio(@fechaIniCalc, @fechaFinCalc, @cia, @person, @feriado, periodo),
        comision_cts = dbo.f_getSumaConceptoPromedio(@fechaIniCalc, @fechaFinCalc, @cia, @person, @comision, periodo),
        faltas_cts =
            ISNULL(dbo.f_getSumaConceptoPromedio(@fechaIniCalc, @fechaFinCalc, @cia, @person, @faltas, periodo), 0)
          + ISNULL(dbo.f_getSumaConceptoPromedio(@fechaIniCalc, @fechaFinCalc, @cia, @person, @lsg, periodo), 0)
          + ISNULL(dbo.f_getSumaConceptoPromedio(@fechaIniCalc, @fechaFinCalc, @cia, @person, @susp, periodo), 0);

    SELECT
        LEFT(periodo, 4) + '-' + SUBSTRING(periodo, 5, 2) AS periodo_fmt,
        he_cts,
        bono_cts,
        feriado_cts,
        comision_cts,
        faltas_cts,
        dbo.f_getMesesDividir(@fechaIniCalc, @fechaFinCalc) AS ctsCant,
        SY_Person.Name,
        CONVERT(VARCHAR(20), @fechaingreso, 103) AS fechaingreso,
        CASE
            WHEN @ceasedate IS NULL THEN ''
            ELSE CONVERT(VARCHAR(20), @ceasedate, 103)
        END AS fechacese
    FROM #temp_reporte
    INNER JOIN SY_Person
        ON #temp_reporte.person = SY_Person.Person
    ORDER BY periodo DESC;
END
GO
