/*
    Ausencias del periodo vacacional (hm_ultra).

    Ubica las vacaciones del trabajador registradas en @period (PR_VacationDetail) y su
    periodo vacacional (PR_Vacation.ControlYear). Sobre el rango de provisión
    DateBeginProvision .. DateBeginRights - 1 día devuelve en @dias la suma de:
        f_getDiasFalta (CANT_DIAS_AUSENCIA) + f_getDiasLSG (licencia sin goce) + f_getDiasSUSP (suspensión).

    Se asume que el trabajador toma sus vacaciones de un solo periodo vacacional en @period;
    si hubiera más de uno, suma las ausencias de cada periodo vacacional.
    Sin vacaciones en @period devuelve 0.

    Uso directo:
        DECLARE @d numeric(19,4);
        EXEC dbo.sp_pr_obtenerAusenciasVacaciones @cia = 'BGT', @person = '16490910', @period = '20261010', @dias = @d OUTPUT;

    Uso en fórmulas (vía sp_pr_formula_exec_proc_web, pasa el trabajador y periodo en cálculo):
        LET AUSENCIAS = PROC("sp_pr_obtenerAusenciasVacaciones")
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_obtenerAusenciasVacaciones
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
    IF @cia = '' OR @person = '' OR @period = ''
        RETURN;

    SELECT @dias = ISNULL(SUM(
               dbo.f_getDiasFalta(V.FechaIni, V.FechaFin, @cia, @person)
             + dbo.f_getDiasLSG(V.FechaIni, V.FechaFin, @cia, @person)
             + dbo.f_getDiasSUSP(V.FechaIni, V.FechaFin, @cia, @person)
           ), 0)
    FROM (
        SELECT DISTINCT
            PV.line,
            CONVERT(date, PV.DateBeginProvision) AS FechaIni,
            DATEADD(day, -1, CONVERT(date, PV.DateBeginRights)) AS FechaFin
        FROM dbo.PR_VacationDetail VD (NOLOCK)
        INNER JOIN dbo.PR_Vacation PV (NOLOCK)
            ON PV.Company = VD.Company
           AND PV.Person = VD.Person
           AND PV.line = VD.line
        WHERE VD.Company = @cia
          AND VD.Person = @person
          AND LTRIM(RTRIM(VD.PRPeriod)) = @period
          AND PV.DateBeginProvision IS NOT NULL
          AND PV.DateBeginRights IS NOT NULL
    ) V;
END
GO
