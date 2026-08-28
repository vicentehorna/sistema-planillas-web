/*
    Listado de asignación de conceptos a trabajadores (PR_EmployeeConcept).
    Usado por: POST /api/asignacion-conceptos/listado (asignacion_conceptos.html).

    Basado en DataWindow legacy (AUXILIARES/Lista de asignacion.txt).

    Filtros iniciales:
      @par_company, @par_payrolltype, @par_period ('0' = todos los periodos),
      @par_concept ('0' = todos los conceptos), @par_person ('0' = todos los empleados),
      @nombre (búsqueda parcial, opcional), @cesados (T/Y/N),
      @par_frecuencytype ('0' = todos, P = permanente, T = temporal),
      @par_replicationunit ('0' = todas las unidades, SY_Person.ReplicationUnit).

    Filtros legacy no expuestos aún (valores por defecto):
      centro de costo = todos, viewliq = T, tareo = N, validar = T.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listaasignacionconceptos_web]
    @par_company     VARCHAR(10),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(10),
    @par_concept     VARCHAR(20),
    @par_person      VARCHAR(20) = '0',
    @nombre          VARCHAR(100),
    @cesados         CHAR(1),
    @par_frecuencytype CHAR(1) = '0',
    @par_replicationunit VARCHAR(4) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @par_period_all  CHAR(1) = 'N';
    DECLARE @par_allconcept  CHAR(1) = 'N';
    DECLARE @par_employee_all CHAR(1) = 'Y';
    DECLARE @person_filter   VARCHAR(20) = '';
    DECLARE @par_cc_all      CHAR(1) = 'Y';
    DECLARE @par_cc          VARCHAR(20) = '';
    DECLARE @par_frecuency_all CHAR(1) = 'N';
    DECLARE @par_frecuency   CHAR(1) = '';
    DECLARE @par_repunit_all CHAR(1) = 'Y';
    DECLARE @par_repunit     VARCHAR(4) = '';
    DECLARE @par_viewliq     CHAR(1) = 'T';
    DECLARE @par_tareo       CHAR(1) = 'N';
    DECLARE @par_validar     CHAR(1) = 'T';

    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@par_period, '')) IN ('', '0') SET @par_period_all = 'Y';
    IF RTRIM(ISNULL(@par_concept, '')) IN ('', '0') SET @par_allconcept = 'Y';
    IF @nombre IS NULL SET @nombre = '';
    SET @nombre = LTRIM(RTRIM(@nombre));
    SET @person_filter = LTRIM(RTRIM(ISNULL(@par_person, '')));
    IF @person_filter IN ('', '0')
        SET @par_employee_all = 'Y';
    ELSE
        SET @par_employee_all = 'N';
    SET @par_frecuencytype = UPPER(LTRIM(RTRIM(ISNULL(@par_frecuencytype, '0'))));
    IF @par_frecuencytype IN ('', '0')
        SET @par_frecuency_all = 'Y';
    ELSE IF @par_frecuencytype IN ('P', 'T')
        SET @par_frecuency = @par_frecuencytype;
    ELSE
        SET @par_frecuency_all = 'Y';

    SET @par_repunit = LTRIM(RTRIM(ISNULL(@par_replicationunit, '')));
    IF @par_repunit IN ('', '0')
        SET @par_repunit_all = 'Y';
    ELSE
        SET @par_repunit_all = 'N';

    SELECT
        ec.Person AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS nombre,
        ISNULL(e.EmployeeCode, ec.Person) AS employeecode,
        ec.Company AS company,
        ec.Concept AS concept,
        (
            SELECT TOP 1 c.Description
            FROM PR_Concept c
            WHERE c.Company = ec.Company
              AND c.Concept = ec.Concept
        ) AS conceptname,
        ec.PayRollType AS payrolltype,
        ec.PRPeriodStart AS prperiodstart,
        ec.PRPeriodEnd AS prperiodend,
        ec.ConceptValue AS conceptvalue,
        ec.ConceptCurrency AS conceptcurrency,
        ec.FlagApplyFormula AS flagapplyformula,
        ec.FlagFrecuencyType AS flagfrecuencytype,
        ec.CostCenter AS costcenter,
        ec.CostCenterCode AS costcentercode,
        ec.Project AS project,
        ec.Comments AS comments,
        CASE WHEN ec.XLastUser = 'TAREO' THEN 'T' ELSE '' END AS tareo,
        ec.XLastUser AS xlastuser,
        ec.XLastDate AS xlastdate,
        LTRIM(RTRIM(
            COALESCE(
                NULLIF(LTRIM(RTRIM(audit_u.nombre)), ''),
                NULLIF(LTRIM(RTRIM(ec.XLastUser)), '')
            )
        )) AS xlastusername
    FROM PR_EmployeeConcept ec WITH (NOLOCK)
        INNER JOIN PR_Employee e WITH (NOLOCK)
            ON e.Person = ec.Person
           AND e.Company = ec.Company
        INNER JOIN SY_Person sp WITH (NOLOCK)
            ON sp.Person = e.Person
        OUTER APPLY (
            SELECT TOP 1 LTRIM(RTRIM(ISNULL(ap.Name, ''))) AS nombre
            FROM SY_User u (NOLOCK)
            LEFT JOIN SY_Person ap (NOLOCK) ON ap.UserID = u.UserID
            WHERE u.UserID = ec.XLastUser
            ORDER BY ap.Person
        ) audit_u
    WHERE e.Person = ec.Person
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ec.Company = @par_company
      AND e.Company = @par_company
      AND (@par_allconcept = 'Y' OR ec.Concept = @par_concept)
      AND ec.PayRollType = @par_payrolltype
      AND (
            @par_employee_all = 'Y'
         OR ec.Person = @person_filter
      )
      AND (
            @par_period_all = 'Y'
         OR (
                (
                    CASE
                        WHEN ec.PRPeriodEnd IS NULL THEN 'N'
                        WHEN RTRIM(ec.PRPeriodEnd) = '' THEN 'N'
                        ELSE 'Y'
                    END = 'N'
                    AND ec.PRPeriodStart <= @par_period
                )
             OR (@par_period BETWEEN ec.PRPeriodStart AND ec.PRPeriodEnd)
            )
      )
      AND (
            @par_cc_all = 'Y'
         OR ec.CostCenter = @par_cc
      )
      AND (
            @par_frecuency_all = 'Y'
         OR ec.FlagFrecuencyType = @par_frecuency
      )
      AND (
            @par_repunit_all = 'Y'
         OR sp.ReplicationUnit = @par_repunit
      )
      AND (
            @par_viewliq = 'T'
         OR (@par_viewliq = 'N' AND e.CeaseDate IS NULL)
         OR (
                @par_period_all = 'Y'
            AND @par_viewliq = 'L'
            AND e.CeaseDate IS NOT NULL
            )
         OR (
                @par_period_all = 'N'
            AND @par_viewliq = 'L'
            AND (
                    SELECT COUNT(*)
                    FROM PR_Period p
                    WHERE p.Company = @par_company
                      AND e.PayRollType = p.PayRollType
                      AND p.PRPeriod = @par_period
                      AND CONVERT(VARCHAR, e.CeaseDate, 112)
                          BETWEEN CONVERT(VARCHAR, p.DateBegin, 112)
                              AND CONVERT(VARCHAR, p.DateEnd, 112)
                ) = 1
            )
      )
      AND (
            @par_tareo = 'N'
         OR ec.XLastUser = 'TAREO'
      )
      AND (
            @par_validar = 'T'
         OR (@par_validar = 'P' AND ISNULL(sp.IsRecruiter, 'N') = 'N')
         OR (@par_validar = 'H' AND ISNULL(sp.IsRecruiter, 'N') = 'Y')
      )
      AND (
            @nombre = ''
         OR LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) LIKE '%' + @nombre + '%'
      )
    ORDER BY nombre, ec.Person, ec.Concept, ec.PRPeriodStart;
END
GO
