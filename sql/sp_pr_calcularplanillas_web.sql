/*
    Trabajadores elegibles para el cálculo de planilla (módulo Procesar planilla).
    Devuelve nombre, person, fechas de ingreso/reingreso, cese y última fecha de cálculo.

    @cia, @payrolltype, @processtype, @period: obligatorios para fecha de cálculo.
    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
    @repunit: '0' = todas las unidades; otro valor filtra SY_Person.ReplicationUnit.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_calcularplanillas_web]
    @cia          VARCHAR(10),
    @payrolltype  VARCHAR(20),
    @processtype  VARCHAR(20),
    @period       VARCHAR(10),
    @cesados      CHAR(1),
    @repunit      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia, ''))), 10);
    SET @payrolltype = LEFT(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), 20);
    SET @processtype = LEFT(LTRIM(RTRIM(ISNULL(@processtype, ''))), 20);
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 10);

    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';

    SELECT
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS [name],
        PR_EMPLOYEE.PERSON AS person,
        PR_EMPLOYEE.COMPANY AS company,
        PR_EMPLOYEE.PAYROLLTYPE AS payrolltype,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS entrydate,
        PR_EMPLOYEE.CEASEDATE AS ceasedate,
        EPR.XLastDate AS calculationdate
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_EmployeePayRoll EPR
            ON EPR.Person = PR_EMPLOYEE.Person
           AND EPR.Company = @cia
           AND EPR.PayRollType = @payrolltype
           AND EPR.ProcessType = @processtype
           AND LTRIM(RTRIM(EPR.PRPeriod)) = @period
    WHERE PR_EMPLOYEE.COMPANY = @cia
      AND PR_EMPLOYEE.PAYROLLTYPE = @payrolltype
      AND PR_EMPLOYEE.STATUS = 'N'
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND PR_EMPLOYEE.CEASEDATE IS NOT NULL)
         OR (@cesados = 'N' AND PR_EMPLOYEE.CEASEDATE IS NULL)
      )
      AND (@repunit = '0' OR SY_PERSON.REPLICATIONUNIT = @repunit)
    ORDER BY [name], person;
END
GO
