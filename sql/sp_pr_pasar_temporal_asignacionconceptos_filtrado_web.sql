/*
    Pasa a Temporal las asignaciones Permanentes (PR_EmployeeConcept) que cumplen
    los mismos filtros que sp_pr_listaasignacionconceptos_web, fijando PRPeriodEnd.

    No modifica registros cuyo periodo inicio sea posterior al periodo fin indicado.

    Devuelve: actualizados (INT), omitidos (INT), mensaje (VARCHAR).

    Usado por: POST /api/asignacion-conceptos/pasar-temporal
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_pasar_temporal_asignacionconceptos_filtrado_web]
    @par_company     VARCHAR(10),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(10),
    @par_concept     VARCHAR(20),
    @par_person      VARCHAR(20) = '0',
    @nombre          VARCHAR(100),
    @cesados         CHAR(1),
    @par_frecuencytype CHAR(1) = '0',
    @par_replicationunit VARCHAR(4) = '0',
    @par_prperiodend VARCHAR(10),
    @xlastuser       VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @par_period_all  CHAR(1) = 'N';
    DECLARE @par_allconcept  CHAR(1) = 'N';
    DECLARE @par_employee_all CHAR(1) = 'Y';
    DECLARE @person_filter   VARCHAR(20) = '';
    DECLARE @par_repunit_all CHAR(1) = 'Y';
    DECLARE @par_repunit     VARCHAR(4) = '';
    DECLARE @actualizados    INT = 0;
    DECLARE @omitidos        INT = 0;

    SET @par_company = LTRIM(RTRIM(ISNULL(@par_company, '')));
    SET @par_payrolltype = LTRIM(RTRIM(ISNULL(@par_payrolltype, '')));
    SET @par_prperiodend = LTRIM(RTRIM(ISNULL(@par_prperiodend, '')));

    IF @par_company = '' OR @par_payrolltype = ''
    BEGIN
        RAISERROR('Seleccione compañía y tipo de planilla.', 16, 1);
        RETURN;
    END;

    IF @par_prperiodend = ''
    BEGIN
        RAISERROR('Indique el periodo fin.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM PR_Period p
        WHERE p.Company = @par_company
          AND p.PayRollType = @par_payrolltype
          AND p.PRPeriod = @par_prperiodend
    )
    BEGIN
        RAISERROR('El periodo fin no existe para la planilla seleccionada.', 16, 1);
        RETURN;
    END;

    /* Solo se pasan a temporal registros permanentes: un filtro "Temporal" no deja nada que actualizar. */
    SET @par_frecuencytype = UPPER(LTRIM(RTRIM(ISNULL(@par_frecuencytype, '0'))));
    IF @par_frecuencytype = 'T'
    BEGIN
        SELECT 0 AS actualizados, 0 AS omitidos,
               'No hay asignaciones permanentes en el filtro (Tipo concepto = Temporal).' AS mensaje;
        RETURN;
    END;

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

    SET @par_repunit = LTRIM(RTRIM(ISNULL(@par_replicationunit, '')));
    IF @par_repunit IN ('', '0')
        SET @par_repunit_all = 'Y';
    ELSE
        SET @par_repunit_all = 'N';

    CREATE TABLE #objetivo (
        Person        VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
        Concept       VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL,
        PRPeriodStart VARCHAR(10) COLLATE DATABASE_DEFAULT NOT NULL,
        CostCenter    VARCHAR(20) COLLATE DATABASE_DEFAULT NOT NULL
    );

    INSERT INTO #objetivo (Person, Concept, PRPeriodStart, CostCenter)
    SELECT ec.Person, ec.Concept, ec.PRPeriodStart, ISNULL(ec.CostCenter, '')
    FROM PR_EmployeeConcept ec
        INNER JOIN PR_Employee e
            ON e.Person = ec.Person
           AND e.Company = ec.Company
        INNER JOIN SY_Person sp
            ON sp.Person = e.Person
    WHERE (
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
      AND ec.FlagFrecuencyType = 'P'
      AND (
            @par_repunit_all = 'Y'
         OR sp.ReplicationUnit = @par_repunit
      )
      AND (
            @nombre = ''
         OR LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) LIKE '%' + @nombre + '%'
      );

    SELECT @omitidos = COUNT(*) FROM #objetivo WHERE PRPeriodStart > @par_prperiodend;

    UPDATE ec
    SET FlagFrecuencyType = 'T',
        PRPeriodEnd = @par_prperiodend,
        XLastUser = NULLIF(LTRIM(RTRIM(@xlastuser)), ''),
        XLastDate = GETDATE()
    FROM PR_EmployeeConcept ec
        INNER JOIN #objetivo o
            ON o.Person = ec.Person
           AND o.Concept = ec.Concept
           AND o.PRPeriodStart = ec.PRPeriodStart
           AND o.CostCenter = ISNULL(ec.CostCenter, '')
    WHERE ec.Company = @par_company
      AND ec.PayRollType = @par_payrolltype
      AND ec.FlagFrecuencyType = 'P'
      AND o.PRPeriodStart <= @par_prperiodend;

    SET @actualizados = @@ROWCOUNT;

    DROP TABLE #objetivo;

    SELECT
        @actualizados AS actualizados,
        @omitidos AS omitidos,
        CASE
            WHEN @actualizados = 0 AND @omitidos = 0 THEN 'No hay asignaciones permanentes que coincidan con el filtro.'
            WHEN @actualizados = 1 THEN 'Se pasó 1 asignación a temporal.'
            ELSE 'Se pasaron ' + CONVERT(VARCHAR(20), @actualizados) + ' asignaciones a temporal.'
        END
        + CASE
            WHEN @omitidos = 0 THEN ''
            WHEN @omitidos = 1 THEN ' 1 registro no se modificó porque su periodo inicio es posterior al periodo fin.'
            ELSE ' ' + CONVERT(VARCHAR(20), @omitidos) + ' registros no se modificaron porque su periodo inicio es posterior al periodo fin.'
        END AS mensaje;
END
GO
