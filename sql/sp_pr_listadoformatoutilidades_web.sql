/*
    Formato de Utilidades — listado de trabajadores con concepto de utilidades calculado.

    Basado en la consulta legacy de PowerBuilder: trabajadores con planilla de utilidades
    en el periodo y concepto NETO configurado en PR_Mapping.utilitiesconcept.

    Usado por: POST /get_lista_formato_utilidades

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @processtype  — proceso (UTILIDADES)
      @period       — periodo PRPeriod
      @person       — código persona; '0' = todos
      @nombre       — búsqueda parcial en SY_Person.Name (opcional)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadoformatoutilidades_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20),
    @nombre      VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    SET @nombre = NULLIF(LTRIM(RTRIM(ISNULL(@nombre, ''))), '');

    SELECT DISTINCT
        EPR.Person AS person,
        LTRIM(RTRIM(
            ISNULL(SP.LastName1, '') + ' '
            + ISNULL(SP.LastName2, '') + ' '
            + ISNULL(SP.Name1, '') + ' '
            + ISNULL(SP.Name2, '')
        )) AS nombre,
        EPR.entrydate AS fechaingreso,
        EPR.ceasedate AS fechacese,
        SP.EMail AS email,
        ISNULL(SP.Sex, 0) AS sex
    FROM PR_Mapping M (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Company = M.Company
        INNER JOIN SY_Person SP (NOLOCK)
            ON E.Person = SP.Person
        INNER JOIN PR_EmployeePayRoll EPR (NOLOCK)
            ON EPR.Company = E.Company
           AND EPR.Person = E.Person
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON EPR.ProcessType = PT.ProcessType
           AND EPR.Company = PT.Company
        INNER JOIN PR_Period PER (NOLOCK)
            ON PER.PayRollType = @payrolltype
           AND PER.PRPeriod = @period
        INNER JOIN PR_EmployeePayRollConcept EPC (NOLOCK)
            ON EPC.Company = @cia
           AND EPC.PayRollType = @payrolltype
           AND EPC.Person = EPR.Person
           AND EPC.ProcessType = @processtype
           AND EPC.PRPeriod = @period
           AND EPC.Concept = M.utilitiesconcept
    WHERE M.Company = @cia
      AND EPR.Company = @cia
      AND EPR.PayRollType = @payrolltype
      AND EPR.ProcessType = @processtype
      AND EPR.PRPeriod = @period
      AND (@person = '0' OR EPR.Person = @person)
      AND (
            @nombre IS NULL
         OR SP.Name LIKE '%' + @nombre + '%'
         OR LTRIM(RTRIM(
                ISNULL(SP.LastName1, '') + ' '
                + ISNULL(SP.LastName2, '') + ' '
                + ISNULL(SP.Name1, '') + ' '
                + ISNULL(SP.Name2, '')
            )) LIKE '%' + @nombre + '%'
      )
    ORDER BY 2;
END
GO
