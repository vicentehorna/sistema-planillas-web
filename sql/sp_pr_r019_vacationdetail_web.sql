/*
    Detalle de vacaciones por trabajador (reporte R019).
    Usado por: POST /reporte_vacaciones_detalle (reporte_vacaciones_detalle.html).

    Parámetros:
      @cia, @payrolltype — obligatorios.
      @period — '0' = todos los periodos; otro valor filtra por YYYYMM (primeros 6 caracteres).
      @person — '0' = todos los trabajadores; otro valor filtra por código person.

    Solo trabajadores activos (PR_Employee.Status = 'N').
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_r019_vacationdetail_web]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20),
    @period       VARCHAR(20),
    @person       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@period, '')) = '' SET @period = '0';

    SELECT
        vd.PRPeriod AS prperiod,
        e.Person AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS name,
        vd.DateBegin AS datebegin,
        vd.DateEnd AS dateend,
        vd.Days AS days,
        v.ControlYear AS controlyear,
        sp.DocumentNumber AS documentnumber,
        pos.Description AS cargo
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
        INNER JOIN PR_PayRollType pt (NOLOCK)
            ON e.PayRollType = pt.PayRollType
        LEFT JOIN PR_Position pos (NOLOCK)
            ON e.Position = pos.Position
    WHERE vd.Company = @cia
      AND e.PayRollType = @payrolltype
      AND (@person = '0' OR e.Person = @person)
      AND (@period = '0' OR LEFT(vd.PRPeriod, 6) = LEFT(@period, 6))
      AND e.Status = 'N'
    ORDER BY name, person, vd.DateBegin;
END
GO
