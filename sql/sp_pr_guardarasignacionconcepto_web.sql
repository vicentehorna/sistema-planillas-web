/*
    Inserta o actualiza una asignación de concepto (PR_EmployeeConcept).
    @modo: I = nuevo, U = actualizar.

    Campos no expuestos en UI (valores por defecto):
      PercentageDistribution = 'A', Application = NULL,
      Project/ProjectCode = '', FlagCopy = NULL.

    Reglas:
      Permanente (P): PRPeriodEnd = NULL.
      Temporal (T): PRPeriodStart y PRPeriodEnd obligatorios; fin >= inicio.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarasignacionconcepto_web]
    @modo                CHAR(1),
    @par_company         VARCHAR(10),
    @par_person          VARCHAR(20),
    @par_concept         VARCHAR(20),
    @par_payrolltype     VARCHAR(20),
    @par_prperiodstart   VARCHAR(10),
    @par_costcenter      VARCHAR(20),
    @par_prperiodend     VARCHAR(10),
    @par_conceptvalue    NUMERIC(18, 4),
    @par_conceptcurrency CHAR(2),
    @par_flagapplyformula CHAR(1),
    @par_flagfrecuencytype CHAR(1),
    @xlastuser           VARCHAR(20) = NULL,
    @par_comments        VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @costcenter      VARCHAR(20);
    DECLARE @costcentercode  VARCHAR(20);
    DECLARE @replicationunit VARCHAR(4);
    DECLARE @conceptvaluelo  NUMERIC(18, 4);
    DECLARE @conceptvalueex  NUMERIC(18, 4);
    DECLARE @exchangerate    NUMERIC(18, 4);

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido.', 16, 1);
        RETURN;
    END

    SET @par_company = LTRIM(RTRIM(ISNULL(@par_company, '')));
    SET @par_person = LTRIM(RTRIM(ISNULL(@par_person, '')));
    SET @par_concept = LTRIM(RTRIM(ISNULL(@par_concept, '')));
    SET @par_payrolltype = LTRIM(RTRIM(ISNULL(@par_payrolltype, '')));
    SET @par_prperiodstart = LTRIM(RTRIM(ISNULL(@par_prperiodstart, '')));
    SET @par_costcenter = LTRIM(RTRIM(ISNULL(@par_costcenter, '')));
    SET @par_prperiodend = NULLIF(LTRIM(RTRIM(ISNULL(@par_prperiodend, ''))), '');
    SET @par_conceptcurrency = UPPER(LTRIM(RTRIM(ISNULL(@par_conceptcurrency, 'LO'))));
    SET @par_flagapplyformula = UPPER(LTRIM(RTRIM(ISNULL(@par_flagapplyformula, 'N'))));
    SET @par_flagfrecuencytype = UPPER(LTRIM(RTRIM(ISNULL(@par_flagfrecuencytype, 'P'))));
    SET @par_comments = NULLIF(LTRIM(RTRIM(ISNULL(@par_comments, ''))), '');

    IF @par_company = '' OR @par_person = '' OR @par_concept = '' OR @par_payrolltype = '' OR @par_prperiodstart = ''
    BEGIN
        RAISERROR('Complete compañía, empleado, concepto, tipo planilla y periodo inicio.', 16, 1);
        RETURN;
    END

    IF @par_conceptvalue IS NULL
    BEGIN
        RAISERROR('Indique el valor del concepto.', 16, 1);
        RETURN;
    END

    IF @par_conceptcurrency NOT IN ('LO', 'EX')
    BEGIN
        RAISERROR('Moneda inválida. Use LO o EX.', 16, 1);
        RETURN;
    END

    IF @par_flagfrecuencytype NOT IN ('P', 'T')
    BEGIN
        RAISERROR('Tipo de asignación inválido. Use Permanente (P) o Temporal (T).', 16, 1);
        RETURN;
    END

    IF @par_flagapplyformula NOT IN ('Y', 'N')
        SET @par_flagapplyformula = 'N';

    IF @par_flagfrecuencytype = 'P'
        SET @par_prperiodend = NULL;
    ELSE IF @par_prperiodend IS NULL
    BEGIN
        RAISERROR('Para asignación temporal indique el periodo fin.', 16, 1);
        RETURN;
    END
    ELSE IF @par_prperiodend < @par_prperiodstart
    BEGIN
        RAISERROR('El periodo fin no puede ser anterior al periodo inicio.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM PR_Employee e
        WHERE e.Company = @par_company
          AND e.Person = @par_person
          AND e.PayRollType = @par_payrolltype
    )
    BEGIN
        RAISERROR('El trabajador no existe o no pertenece al tipo de planilla indicado.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM PR_Concept c
        WHERE c.Company = @par_company
          AND c.Concept = @par_concept
          AND c.Status = 'A'
    )
    BEGIN
        RAISERROR('El concepto no existe o no está activo para la compañía.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM PR_Period p
        WHERE p.Company = @par_company
          AND p.PayRollType = @par_payrolltype
          AND p.PRPeriod = @par_prperiodstart
    )
    BEGIN
        RAISERROR('El periodo inicio no existe para la planilla seleccionada.', 16, 1);
        RETURN;
    END

    IF @par_flagfrecuencytype = 'T'
       AND NOT EXISTS (
            SELECT 1 FROM PR_Period p
            WHERE p.Company = @par_company
              AND p.PayRollType = @par_payrolltype
              AND p.PRPeriod = @par_prperiodend
       )
    BEGIN
        RAISERROR('El periodo fin no existe para la planilla seleccionada.', 16, 1);
        RETURN;
    END

    SELECT
        @costcenter = ISNULL(NULLIF(LTRIM(RTRIM(e.CostCenter)), ''), ''),
        @costcentercode = ISNULL(
            NULLIF(LTRIM(RTRIM(e.CostCenterName)), ''),
            ISNULL(NULLIF(LTRIM(RTRIM(e.CostCenter)), ''), '')
        ),
        @replicationunit = NULLIF(LTRIM(RTRIM(sp.ReplicationUnit)), '')
    FROM PR_Employee e
        INNER JOIN SY_Person sp ON sp.Person = e.Person
    WHERE e.Company = @par_company
      AND e.Person = @par_person;

    IF @modo = 'I'
    BEGIN
        IF @par_costcenter <> ''
            SET @costcenter = @par_costcenter;

        IF EXISTS (
            SELECT 1 FROM PR_EmployeeConcept ec
            WHERE ec.Person = @par_person
              AND ec.Company = @par_company
              AND ec.Concept = @par_concept
              AND ec.PayRollType = @par_payrolltype
              AND ec.PRPeriodStart = @par_prperiodstart
              AND ec.CostCenter = @costcenter
        )
        BEGIN
            RAISERROR('Ya existe una asignación con la misma clave (trabajador, concepto, planilla, periodo inicio y centro de costo).', 16, 1);
            RETURN;
        END

        IF @par_conceptcurrency = 'LO'
        BEGIN
            SET @conceptvaluelo = @par_conceptvalue;
            SET @conceptvalueex = 0;
            SET @exchangerate = 0;
        END
        ELSE
        BEGIN
            SET @conceptvalueex = @par_conceptvalue;
            SET @conceptvaluelo = 0;
            SET @exchangerate = 1;
        END

        INSERT INTO PR_EmployeeConcept (
            Person, Company, Concept, PayRollType, PRPeriodStart, CostCenter,
            PRPeriodEnd, ConceptValue, Application, ConceptCurrency, Comments,
            FlagApplyFormula, FlagFrecuencyType, ReplicationUnit,
            XLastUser, XLastDate, ConceptValueLo, ConceptValueEx, ExchangeRate,
            CostCenterCode, Project, ProjectCode, PercentageDistribution, FlagCopy
        )
        VALUES (
            @par_person, @par_company, @par_concept, @par_payrolltype, @par_prperiodstart, @costcenter,
            @par_prperiodend, @par_conceptvalue, NULL, @par_conceptcurrency, @par_comments,
            @par_flagapplyformula, @par_flagfrecuencytype, @replicationunit,
            NULLIF(LTRIM(RTRIM(@xlastuser)), ''), GETDATE(), @conceptvaluelo, @conceptvalueex, @exchangerate,
            @costcentercode, '', '', 'A', NULL
        );
    END
    ELSE
    BEGIN
        IF @par_costcenter = ''
            SET @par_costcenter = @costcenter;

        IF NOT EXISTS (
            SELECT 1 FROM PR_EmployeeConcept ec
            WHERE ec.Person = @par_person
              AND ec.Company = @par_company
              AND ec.Concept = @par_concept
              AND ec.PayRollType = @par_payrolltype
              AND ec.PRPeriodStart = @par_prperiodstart
              AND ec.CostCenter = @par_costcenter
        )
        BEGIN
            RAISERROR('No se encontró la asignación a actualizar.', 16, 1);
            RETURN;
        END

        IF @par_conceptcurrency = 'LO'
        BEGIN
            SET @conceptvaluelo = @par_conceptvalue;
            SET @conceptvalueex = 0;
            SET @exchangerate = 0;
        END
        ELSE
        BEGIN
            SET @conceptvalueex = @par_conceptvalue;
            SET @conceptvaluelo = 0;
            SET @exchangerate = 1;
        END

        UPDATE PR_EmployeeConcept
        SET
            PRPeriodEnd = @par_prperiodend,
            ConceptValue = @par_conceptvalue,
            ConceptCurrency = @par_conceptcurrency,
            FlagApplyFormula = @par_flagapplyformula,
            FlagFrecuencyType = @par_flagfrecuencytype,
            Comments = @par_comments,
            ConceptValueLo = @conceptvaluelo,
            ConceptValueEx = @conceptvalueex,
            ExchangeRate = @exchangerate,
            XLastUser = NULLIF(LTRIM(RTRIM(@xlastuser)), ''),
            XLastDate = GETDATE()
        WHERE Person = @par_person
          AND Company = @par_company
          AND Concept = @par_concept
          AND PayRollType = @par_payrolltype
          AND PRPeriodStart = @par_prperiodstart
          AND CostCenter = @par_costcenter;
    END
END
GO
