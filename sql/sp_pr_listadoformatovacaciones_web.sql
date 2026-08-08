/*
    Listado para Formato de Vacaciones (Constancia de Goce Vacacional).
    Filtro de periodo de pago: LEFT(PR_VacationDetail.PRPeriod, 6) = YYYYMM de @fecha
    (misma lógica del DataWindow PowerBuilder).

    @cesados: T = Todos, Y = solo cesados, N = no cesados.
    @person: '0' = todos.
    @anio: '' o '0' = no filtra; si viene, LEFT(PRPeriod,4) = @anio.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadoformatovacaciones_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20),
    @fecha       DATETIME,
    @cesados     CHAR(1) = 'T',
    @person      VARCHAR(20) = '0',
    @anio        VARCHAR(4) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    SET @cesados = UPPER(@cesados);
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';
    IF RTRIM(ISNULL(@anio, '')) = '' SET @anio = '0';
    IF @fecha IS NULL SET @fecha = GETDATE();

    DECLARE @yyyymm VARCHAR(6) = CONVERT(VARCHAR(6), @fecha, 112);

    SELECT
        e.Person AS person,
        vd.Line AS line,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS nombre,
        LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ISNULL(sp.Ruc, '')))) AS dni,
        vd.DateBegin AS datebegin,
        vd.DateEnd AS dateend,
        vd.Days AS days,
        v.ControlYear AS controlyear,
        vd.PRPeriod AS prperiod,
        LTRIM(RTRIM(ISNULL(NULLIF(pos.name, ''), ISNULL(pos.Description, '')))) AS cargo,
        CONVERT(VARCHAR(10), e.EntryDate, 103) AS ingreso,
        CONVERT(VARCHAR(10), e.CeaseDate, 103) AS cese,
        LTRIM(RTRIM(ISNULL(sp.Email, ''))) AS email
    FROM PR_VacationDetail vd
        INNER JOIN PR_Vacation v (NOLOCK)
            ON vd.Person = v.Person
           AND vd.Company = v.Company
           AND vd.Line = v.Line
        INNER JOIN PR_Employee e (NOLOCK)
            ON vd.Person = e.Person
           AND vd.Company = e.Company
        INNER JOIN SY_Person sp (NOLOCK)
            ON vd.Person = sp.Person
        LEFT JOIN PR_Position pos (NOLOCK)
            ON e.Position = pos.Position
    WHERE vd.Company = @cia
      AND e.PayRollType = @payrolltype
      AND LEFT(vd.PRPeriod, 6) = @yyyymm
      AND (@anio = '0' OR LEFT(vd.PRPeriod, 4) = @anio)
      AND (@person = '0' OR e.Person = @person)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND sp.Status = 'A'
    ORDER BY nombre, person, vd.DateBegin, vd.Line;
END
GO
