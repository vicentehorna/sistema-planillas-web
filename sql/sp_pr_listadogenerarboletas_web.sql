/*
    Generar boletas — listado de trabajadores con planilla calculada en el periodo.

    Usado por: POST /get_lista_boletas, descargar ZIP y envío masivo de boletas.

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @processtype  — proceso
      @period       — periodo PRPeriod
      @person       — código persona; '0' = todos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadogenerarboletas_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PR_EmployeePayRoll.Person AS person,
        SY_Person.Name AS nombre,
        PR_EmployeePayRoll.entrydate AS fechaingreso,
        PR_EmployeePayRoll.ceasedate AS fechacese,
        SY_Person.EMail AS email,
        ISNULL(SY_Person.Sex, 0) AS sex
    FROM PR_EmployeePayRoll
        INNER JOIN SY_Person ON PR_EmployeePayRoll.Person = SY_Person.Person
    WHERE PR_EmployeePayRoll.Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND PRPeriod = @period
      AND (@person = '0' OR PR_EmployeePayRoll.Person = @person)
    ORDER BY 2;
END
GO
