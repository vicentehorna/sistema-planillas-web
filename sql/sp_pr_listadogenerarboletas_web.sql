/*
    Generar boletas — listado de trabajadores con planilla calculada en el periodo.

    Usado por: POST /get_lista_boletas, descargar ZIP y envío masivo de boletas.

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @processtype  — proceso
      @period       — periodo PRPeriod
      @person       — código persona; '0' = todos
      @nombre       — búsqueda parcial en SY_Person.Name (opcional)
      @repunit      — '0' = todas las unidades; otro valor filtra SY_Person.ReplicationUnit
      @costcenter   — '0' = todos; otro valor filtra PR_Employee.CostCenter
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadogenerarboletas_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20),
    @nombre      VARCHAR(80) = NULL,
    @repunit     VARCHAR(20) = '0',
    @costcenter  VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    SET @nombre = NULLIF(LTRIM(RTRIM(ISNULL(@nombre, ''))), '');
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';
    IF RTRIM(ISNULL(@costcenter, '')) = '' SET @costcenter = '0';

    SELECT
        PR_EmployeePayRoll.Person AS person,
        SY_Person.Name AS nombre,
        PR_EmployeePayRoll.entrydate AS fechaingreso,
        PR_EmployeePayRoll.ceasedate AS fechacese,
        SY_Person.EMail AS email,
        ISNULL(SY_Person.Sex, 0) AS sex
    FROM PR_EmployeePayRoll
        INNER JOIN SY_Person
            ON PR_EmployeePayRoll.Person = SY_Person.Person
        LEFT JOIN PR_Employee E
            ON E.Company = PR_EmployeePayRoll.Company
           AND E.Person = PR_EmployeePayRoll.Person
           AND E.PayRollType = PR_EmployeePayRoll.PayRollType
    WHERE PR_EmployeePayRoll.Company = @cia
      AND PR_EmployeePayRoll.PayRollType = @payrolltype
      AND PR_EmployeePayRoll.ProcessType = @processtype
      AND PR_EmployeePayRoll.PRPeriod = @period
      AND (@person = '0' OR PR_EmployeePayRoll.Person = @person)
      AND (
            @nombre IS NULL
         OR SY_Person.Name LIKE '%' + @nombre + '%'
      )
      AND (@repunit = '0' OR SY_Person.ReplicationUnit = @repunit)
      AND (@costcenter = '0' OR LTRIM(RTRIM(ISNULL(E.CostCenter, ''))) = @costcenter)
    ORDER BY 2;
END
GO
