/*
    Formato de CTS — listado de trabajadores con proceso Pago de CTS en el periodo.

    Misma lógica que sp_pr_listadocertificadotrabajo_web, fijando ProcessType = CTS
    (PR_ProcessType.ShortName = 'CTS'; no incluye PROVISION_CTS). Solo trabajadores con
    el concepto CTS (PR_Mapping.CTSConcept) calculado en el periodo.

    Usado por: POST /get_lista_formato_cts

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @period       — periodo PRPeriod
      @person       — código persona; '0' = todos
      @nombre       — búsqueda parcial en SY_Person.Name (opcional)
      @repunit      — '0' = todas las unidades; otro valor filtra SY_Person.ReplicationUnit
      @costcenter   — '0' = todos; otro valor filtra PR_Employee.CostCenter (hm_divisa)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadoformatocts_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
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
        ep.Person AS person,
        SY_Person.Name AS nombre,
        ep.entrydate AS fechaingreso,
        ep.ceasedate AS fechacese,
        SY_Person.EMail AS email,
        ISNULL(SY_Person.Sex, 0) AS sex
    FROM PR_EmployeePayRoll ep
        INNER JOIN SY_Person ON ep.Person = SY_Person.Person
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Company = ep.Company
           AND E.Person = ep.Person
        INNER JOIN PR_ProcessType pt (NOLOCK)
            ON ep.ProcessType = pt.ProcessType
           AND ep.Company = pt.Company
    WHERE ep.Company = @cia
      AND ep.PayRollType = @payrolltype
      AND pt.ShortName = 'CTS'
      AND ep.PRPeriod = @period
      AND (@person = '0' OR ep.Person = @person)
      AND (@repunit = '0' OR SY_Person.ReplicationUnit = @repunit)
      AND (@costcenter = '0' OR LTRIM(RTRIM(ISNULL(E.CostCenter, ''))) = @costcenter)
      AND EXISTS (
            SELECT 1
            FROM PR_EmployeePayRollConcept EPC (NOLOCK)
                INNER JOIN PR_Mapping M (NOLOCK)
                    ON M.Company = EPC.Company
                   AND M.CTSConcept = EPC.Concept
            WHERE EPC.Company = ep.Company
              AND EPC.PayRollType = ep.PayRollType
              AND EPC.ProcessType = ep.ProcessType
              AND EPC.PRPeriod = ep.PRPeriod
              AND EPC.Person = ep.Person
      )
      AND (
            @nombre IS NULL
         OR SY_Person.Name LIKE '%' + @nombre + '%'
      )
    ORDER BY 2;
END
GO
