/*
    Actualiza datos de pensiones del trabajador (PR_Employee).
    Clave: person + company (@cia).
    Fecha inscripción: VARCHAR(10) YYYY-MM-DD o vacío → NULL.

    Además sincroniza asignación permanente AFP_FLUJO / AFP_COMISION_MIXTA:
      - flagmixta=Y y régimen AFP → asegura concepto permanente = 1
      - flagmixta=N (flujo) u ONP → elimina permanentes abiertos del concepto
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_pensiones_trabajador_web]
    @cia                        VARCHAR(10),
    @person                     VARCHAR(20),
    @pensiontype                VARCHAR(20),
    @pensioninscriptiondate     VARCHAR(10) = '',
    @regimehealth               VARCHAR(20),
    @flagmixta                  VARCHAR(1) = 'N',
    @cuspp                      VARCHAR(20) = NULL,
    @xlastuser                  VARCHAR(20) = NULL,
    @flagessaludvida            VARCHAR(1) = NULL  /* NULL = no modificar */
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM pr_employee
        WHERE company = @cia AND person = @person
    )
    BEGIN
        RAISERROR('Trabajador no encontrado para la compañía indicada.', 16, 1);
        RETURN;
    END

    IF RTRIM(ISNULL(@flagmixta, '')) NOT IN ('Y', 'N') SET @flagmixta = 'N';
    SET @flagessaludvida = UPPER(NULLIF(LTRIM(RTRIM(@flagessaludvida)), ''));
    IF @flagessaludvida IS NOT NULL AND @flagessaludvida NOT IN ('Y', 'N') SET @flagessaludvida = 'N';

    DECLARE @fecha_inscripcion DATETIME = NULL;
    DECLARE @afp_id VARCHAR(20) = NULL;
    DECLARE @pension_pdt VARCHAR(20) = NULL;
    DECLARE @pensiontype_norm VARCHAR(20) = NULLIF(LTRIM(RTRIM(@pensiontype)), '');
    DECLARE @tiene_afp CHAR(1) = 'N';
    DECLARE @payrolltype VARCHAR(20) = NULL;
    DECLARE @replicationunit VARCHAR(20) = 'LIMA';
    DECLARE @period_start VARCHAR(10) = NULL;
    DECLARE @costcenter VARCHAR(20) = '';
    DECLARE @costcentercode VARCHAR(20) = '';
    DECLARE @concept_afp VARCHAR(20) = NULL;
    DECLARE @entrydate DATETIME = NULL;

    IF RTRIM(ISNULL(@pensioninscriptiondate, '')) <> ''
       AND ISDATE(@pensioninscriptiondate) = 1
        SET @fecha_inscripcion = CONVERT(DATETIME, @pensioninscriptiondate, 120);

    /* Resolver AFP automáticamente desde el régimen (sin UI). */
    IF @pensiontype_norm IS NOT NULL
    BEGIN
        SELECT @pension_pdt = LTRIM(RTRIM(ISNULL(pt.PDT, '')))
        FROM PR_PensionType pt (NOLOCK)
        WHERE pt.PensionType = @pensiontype_norm;

        IF @pension_pdt IN ('21', '23', '24', '25')
            OR EXISTS (
                SELECT 1
                FROM PR_PensionType pt (NOLOCK)
                WHERE pt.PensionType = @pensiontype_norm
                  AND (
                        UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) LIKE '%SPP%'
                     OR UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) LIKE '%AFP%'
                  )
                  AND UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) NOT LIKE '%ONP%'
            )
        BEGIN
            SET @tiene_afp = 'Y';
            IF @pension_pdt IN ('21', '23', '24', '25')
                SELECT TOP 1 @afp_id = a.AFP
                FROM PR_AFP a (NOLOCK)
                WHERE a.Company = @cia
                  AND LTRIM(RTRIM(ISNULL(a.PDT, ''))) = @pension_pdt
                ORDER BY
                    CASE WHEN a.AFP LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END,
                    a.AFP;
        END;
    END;

    UPDATE pr_employee
    SET
        pensiontype = @pensiontype_norm,
        pensioninscriptiondate = @fecha_inscripcion,
        regimehealth = NULLIF(LTRIM(RTRIM(@regimehealth)), ''),
        flagmixta = @flagmixta,
        flagessaludvida = ISNULL(@flagessaludvida, flagessaludvida),
        afpcard = NULLIF(LTRIM(RTRIM(@cuspp)), ''),
        afp = @afp_id,
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE company = @cia
      AND person = @person;

    /* Concepto flag mixta (FormulaCode AFP_FLUJO; Description suele ser AFP_COMISION_MIXTA) */
    SELECT TOP 1 @concept_afp = c.Concept
    FROM PR_Concept c (NOLOCK)
    WHERE c.Company = @cia
      AND c.Status = 'A'
      AND (
            LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) IN ('AFP_FLUJO', 'AFP_COMISION_MIXTA')
         OR UPPER(LTRIM(RTRIM(ISNULL(c.Description, '')))) = 'AFP_COMISION_MIXTA'
      )
    ORDER BY
        CASE LTRIM(RTRIM(ISNULL(c.FormulaCode, '')))
            WHEN 'AFP_FLUJO' THEN 0
            WHEN 'AFP_COMISION_MIXTA' THEN 1
            ELSE 2
        END,
        c.Concept;

    IF @concept_afp IS NULL
        RETURN;

    SELECT
        @payrolltype = e.PayRollType,
        @costcenter = ISNULL(e.CostCenter, ''),
        @costcentercode = ISNULL(e.Costcentername, ISNULL(e.CostCenter, '')),
        @entrydate = ISNULL(e.ReEntryDate, e.EntryDate)
    FROM PR_Employee e (NOLOCK)
    WHERE e.Company = @cia AND e.Person = @person;

    SELECT TOP 1 @replicationunit = ISNULL(NULLIF(LTRIM(RTRIM(p.ReplicationUnit)), ''), 'LIMA')
    FROM SY_Person p (NOLOCK)
    WHERE p.Person = @person;

    /* Flujo / no AFP: quitar permanentes abiertos del flag mixta */
    IF @flagmixta <> 'Y' OR @tiene_afp <> 'Y'
    BEGIN
        DELETE ec
        FROM PR_EmployeeConcept ec
        INNER JOIN PR_Concept c
            ON c.Concept = ec.Concept AND c.Company = ec.Company
        WHERE ec.Company = @cia
          AND ec.Person = @person
          AND ec.FlagFrecuencyType = 'P'
          AND ec.PRPeriodEnd IS NULL
          AND (
                LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) IN ('AFP_FLUJO', 'AFP_COMISION_MIXTA')
             OR UPPER(LTRIM(RTRIM(ISNULL(c.Description, '')))) = 'AFP_COMISION_MIXTA'
          );
        RETURN;
    END;

    /* Mixta: asegurar permanente = 1 */
    IF @payrolltype IS NULL
        RETURN;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeeConcept ec (NOLOCK)
        WHERE ec.Company = @cia
          AND ec.Person = @person
          AND ec.Concept = @concept_afp
          AND ec.PayRollType = @payrolltype
          AND ec.FlagFrecuencyType = 'P'
          AND ec.PRPeriodEnd IS NULL
    )
    BEGIN
        UPDATE PR_EmployeeConcept
        SET ConceptValue = 1,
            ConceptValueLo = 1,
            ConceptValueEx = 0,
            XLastUser = NULLIF(LTRIM(RTRIM(@xlastuser)), ''),
            XLastDate = GETDATE()
        WHERE Company = @cia
          AND Person = @person
          AND Concept = @concept_afp
          AND PayRollType = @payrolltype
          AND FlagFrecuencyType = 'P'
          AND PRPeriodEnd IS NULL
          AND ISNULL(ConceptValue, 0) <> 1;
        RETURN;
    END;

    IF @entrydate IS NOT NULL
    BEGIN
        SELECT TOP 1 @period_start = p.PRPeriod
        FROM PR_Period p (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype
          AND @entrydate BETWEEN p.DateBegin AND p.DateEnd
        ORDER BY p.PRPeriod;

        IF @period_start IS NULL
            SELECT TOP 1 @period_start = p.PRPeriod
            FROM PR_Period p (NOLOCK)
            WHERE p.Company = @cia
              AND p.PayRollType = @payrolltype
              AND p.DateBegin >= @entrydate
            ORDER BY p.DateBegin ASC, p.PRPeriod ASC;

        IF @period_start IS NULL
            SELECT TOP 1 @period_start = p.PRPeriod
            FROM PR_Period p (NOLOCK)
            WHERE p.Company = @cia
              AND p.PayRollType = @payrolltype
            ORDER BY p.PRPeriod DESC;
    END;

    IF @period_start IS NULL
        RETURN;

    INSERT INTO PR_EmployeeConcept (
        Person, Company, Concept, PayRollType, PRPeriodStart, CostCenter,
        PRPeriodEnd, ConceptValue, Application, ConceptCurrency, Comments,
        FlagApplyFormula, FlagFrecuencyType, ReplicationUnit,
        XLastUser, XLastDate, ConceptValueLo, ConceptValueEx, ExchangeRate,
        CostCenterCode, Project, ProjectCode, PercentageDistribution, FlagCopy
    )
    VALUES (
        @person, @cia, @concept_afp, @payrolltype, @period_start, @costcenter,
        NULL, 1, NULL, 'LO', NULL,
        'N', 'P', @replicationunit,
        NULLIF(LTRIM(RTRIM(@xlastuser)), ''), GETDATE(), 1, 0, 0,
        @costcentercode, '', '', 'A', NULL
    );
END
GO
