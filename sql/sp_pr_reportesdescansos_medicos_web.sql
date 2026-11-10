/*
    Detalle de descansos médicos por trabajador.
    Usado por: POST /reporte_descansos_medicos_detalle (reporte_descansos_medicos_detalle.html).

    Parámetros:
      @cia, @payrolltype — obligatorios.
      @period_desde, @period_hasta — obligatorios (YYYYMM / YYYYMMDD); filtra por LEFT(PRPeriod,6).
      @person — '0' = todos los trabajadores; otro valor filtra por código person.
      @medicalresttype — '0' = todos los tipos; otro valor filtra por PR_MedicalRestType.
      @cesados — T=todos, Y=con fecha de cese, N=sin fecha de cese.
      @activos — T=todos, Y=activos (Status N/vacío), N=inactivos.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportesdescansos_medicos_web]
    @cia               VARCHAR(20),
    @payrolltype       VARCHAR(20),
    @period_desde      VARCHAR(20),
    @period_hasta      VARCHAR(20),
    @person            VARCHAR(20) = '0',
    @medicalresttype   VARCHAR(20) = '0',
    @cesados           CHAR(1) = 'T',
    @activos           CHAR(1) = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@medicalresttype, '')) = '' SET @medicalresttype = '0';

    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    SET @activos = UPPER(LTRIM(RTRIM(ISNULL(@activos, 'T'))));
    IF @activos NOT IN ('T', 'Y', 'N') SET @activos = 'T';

    DECLARE @p_desde VARCHAR(6) = LEFT(LTRIM(RTRIM(ISNULL(@period_desde, ''))), 6);
    DECLARE @p_hasta VARCHAR(6) = LEFT(LTRIM(RTRIM(ISNULL(@period_hasta, ''))), 6);

    IF @p_desde = '' OR @p_hasta = '' OR LEN(@p_desde) < 6 OR LEN(@p_hasta) < 6
    BEGIN
        RAISERROR('Indique periodo inicial y periodo final.', 16, 1);
        RETURN;
    END;

    IF @p_hasta < @p_desde
    BEGIN
        RAISERROR('El periodo final no puede ser menor al periodo inicial.', 16, 1);
        RETURN;
    END;

    SELECT
        PR_EmployeeMedicalRest.PRPeriod AS prperiod,
        SY_Person.Person AS person,
        LTRIM(RTRIM(
            ISNULL(SY_Person.LastName1, '') + ' ' +
            ISNULL(SY_Person.LastName2, '') + ' ' +
            ISNULL(SY_Person.Name1, '') + ' ' +
            ISNULL(SY_Person.Name2, '')
        )) AS name,
        PR_EmployeeMedicalRest.DateBegin AS datebegin,
        PR_EmployeeMedicalRest.DateEnd AS dateend,
        PR_EmployeeMedicalRest.Days AS days,
        PR_MedicalRestType.Description AS description,
        PR_EmployeeMedicalRest.CITT AS citt
    FROM SY_Company
        INNER JOIN PR_Employee
            ON SY_Company.Company = PR_Employee.Company
        INNER JOIN SY_Person
            ON SY_Person.Person = PR_Employee.Person
        INNER JOIN PR_EmployeeMedicalRest
            ON PR_EmployeeMedicalRest.Person = PR_Employee.Person
           AND PR_EmployeeMedicalRest.Company = PR_Employee.Company
        INNER JOIN PR_MedicalRestType
            ON PR_MedicalRestType.MedicalRestType = PR_EmployeeMedicalRest.MedicalRestType
    WHERE PR_EmployeeMedicalRest.Company = @cia
      AND PR_Employee.PayRollType = @payrolltype
      AND (@person = '0' OR PR_Employee.Person = @person)
      AND (@medicalresttype = '0' OR PR_EmployeeMedicalRest.MedicalRestType = @medicalresttype)
      AND LEFT(PR_EmployeeMedicalRest.PRPeriod, 6) >= @p_desde
      AND LEFT(PR_EmployeeMedicalRest.PRPeriod, 6) <= @p_hasta
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND PR_Employee.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND PR_Employee.CeaseDate IS NULL)
      )
      AND (
            @activos = 'T'
         OR (@activos = 'Y' AND LTRIM(RTRIM(ISNULL(PR_Employee.Status, ''))) IN ('', 'N'))
         OR (@activos = 'N' AND LTRIM(RTRIM(ISNULL(PR_Employee.Status, ''))) NOT IN ('', 'N'))
      )
    ORDER BY name, person, PR_EmployeeMedicalRest.DateBegin;
END
GO
