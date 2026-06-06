/*
    Detalle de descansos médicos por trabajador.
    Usado por: POST /reporte_descansos_medicos_detalle (reporte_descansos_medicos_detalle.html).

    Parámetros:
      @cia, @payrolltype — obligatorios.
      @period — '0' = todos los periodos; otro valor filtra por YYYYMM (primeros 6 caracteres).
      @person — '0' = todos los trabajadores; otro valor filtra por código person.
      @medicalresttype — '0' = todos los tipos; otro valor filtra por PR_MedicalRestType.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportesdescansos_medicos_web]
    @cia               VARCHAR(20),
    @payrolltype       VARCHAR(20),
    @period            VARCHAR(20),
    @person            VARCHAR(20),
    @medicalresttype   VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@period, '')) = '' SET @period = '0';
    IF RTRIM(ISNULL(@medicalresttype, '')) = '' SET @medicalresttype = '0';

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
      AND (@period = '0' OR LEFT(PR_EmployeeMedicalRest.PRPeriod, 6) = LEFT(@period, 6))
    ORDER BY name, person, PR_EmployeeMedicalRest.DateBegin;
END
GO
