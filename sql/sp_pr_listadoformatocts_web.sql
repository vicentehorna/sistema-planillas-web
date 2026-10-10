/*
    Formato de CTS — listado de trabajadores con proceso Pago de CTS en el periodo.

    Misma lógica que sp_pr_listadocertificadotrabajo_web, fijando ProcessType = CTS
    (PR_ProcessType.ShortName = 'CTS'; no incluye PROVISION_CTS).

    Usado por: POST /get_lista_formato_cts

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @period       — periodo PRPeriod
      @person       — código persona; '0' = todos
      @nombre       — búsqueda parcial en SY_Person.Name (opcional)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadoformatocts_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20),
    @nombre      VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @nombre = NULLIF(LTRIM(RTRIM(ISNULL(@nombre, ''))), '');

    SELECT
        PR_EmployeePayRoll.Person AS person,
        SY_Person.Name AS nombre,
        PR_EmployeePayRoll.entrydate AS fechaingreso,
        PR_EmployeePayRoll.ceasedate AS fechacese,
        SY_Person.EMail AS email,
        ISNULL(SY_Person.Sex, 0) AS sex
    FROM PR_EmployeePayRoll
        INNER JOIN SY_Person ON PR_EmployeePayRoll.Person = SY_Person.Person
        INNER JOIN PR_ProcessType pt (NOLOCK)
            ON PR_EmployeePayRoll.ProcessType = pt.ProcessType
           AND PR_EmployeePayRoll.Company = pt.Company
    WHERE PR_EmployeePayRoll.Company = @cia
      AND PayRollType = @payrolltype
      AND pt.ShortName = 'CTS'
      AND PRPeriod = @period
      AND (@person = '0' OR PR_EmployeePayRoll.Person = @person)
      AND (
            @nombre IS NULL
         OR SY_Person.Name LIKE '%' + @nombre + '%'
      )
    ORDER BY 2;
END
GO
