/*
    Alta manual de trabajador desde la ficha web (Nuevo).

    Inserta SY_Person + PR_Employee.
    - Name = ApellidoPaterno + ApellidoMaterno + Nombre1 + Nombre2
    - EntryDate = ReEntryDate
    - Si régimen AFP: resuelve PR_Employee.AFP desde PR_AFP (sin UI)
    - Si sueldo > 0: asigna REM_BASICA permanente (salvo Construcción Civil)
    - Si AFP: asigna AFP_FLUJO = 1

    Validaciones bloqueantes:
      - Código (person) único en SY_Person
      - Documento no existente ya en la misma compañía

    @confirmar_nombre = 'Y' permite continuar pese a nombres similares
    (la UI debe haber pedido confirmación vía sp_pr_validar_alta_trabajador_web).

    Usado por: POST /trabajadores/nuevo
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_registrar_trabajador_web]
    @cia                    VARCHAR(10),
    @person                 VARCHAR(20),
    @name1                  VARCHAR(40),
    @name2                  VARCHAR(40) = NULL,
    @lastname1              VARCHAR(40),
    @lastname2              VARCHAR(40) = NULL,
    @birthdate              VARCHAR(10) = NULL,
    @sex                    CHAR(1),
    @sectelephone           VARCHAR(15) = NULL,
    @email                  VARCHAR(255) = NULL,
    @address                VARCHAR(255) = NULL,
    @nacionalidad           VARCHAR(100) = NULL,
    @employeedocumenttype   VARCHAR(20),
    @documentnumber         VARCHAR(15),
    @replicationunit        VARCHAR(4),
    @userid                 VARCHAR(20) = NULL,
    @employeetype           VARCHAR(20),
    @employeecategory       VARCHAR(20) = NULL,
    @entrydate              VARCHAR(10),
    @contractmodality       VARCHAR(20) = NULL,
    @ocupation              VARCHAR(20) = NULL,
    @specialstatus          VARCHAR(20) = NULL,
    @position               VARCHAR(20) = NULL,
    @costcenter             VARCHAR(20),
    @payrolltype            VARCHAR(20),
    @accountprofile         VARCHAR(20) = NULL,
    @sueldo                 VARCHAR(20) = NULL,
    @flagasigfamiliar       CHAR(1) = 'N',
    @pensiontype            VARCHAR(20) = NULL,
    @pensioninscriptiondate VARCHAR(10) = NULL,
    @regimehealth           VARCHAR(20) = NULL,
    @flagmixta              CHAR(1) = 'N',
    @cuspp                  VARCHAR(20) = NULL,
    @collectionform         VARCHAR(20) = NULL,
    @salarybank             VARCHAR(20) = NULL,
    @salaryaccounttype      VARCHAR(20) = NULL,
    @salaryaccount          VARCHAR(20) = NULL,
    @cci                    VARCHAR(20) = NULL,
    @ctsbank                VARCHAR(20) = NULL,
    @ctsaccount             VARCHAR(20) = NULL,
    @ctscurrency            CHAR(2) = 'LO',
    @confirmar_nombre       CHAR(1) = 'N',
    @xlastuser              VARCHAR(20) = NULL,
    @person_out             VARCHAR(20) = NULL OUTPUT,
    @mensaje_out            VARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nombre_completo    VARCHAR(100);
    DECLARE @birthdate_dt       DATETIME;
    DECLARE @entrydate_dt       DATETIME;
    DECLARE @pensiondate_dt     DATETIME;
    DECLARE @rembasica          NUMERIC(18, 4) = NULL;
    DECLARE @costcentername     VARCHAR(20) = NULL;
    DECLARE @employee_status_id VARCHAR(20) = NULL;
    DECLARE @afp_id             VARCHAR(20) = NULL;
    DECLARE @pension_pdt        VARCHAR(20) = NULL;
    DECLARE @tiene_afp          CHAR(1) = 'N';
    DECLARE @userid_norm        VARCHAR(20);
    DECLARE @doc_norm           VARCHAR(15);
    DECLARE @es_construccion    CHAR(1) = 'N';
    DECLARE @concept_rembasica  VARCHAR(20);
    DECLARE @concept_afp_flujo  VARCHAR(20);
    DECLARE @period_start       VARCHAR(10);
    DECLARE @cc_asignacion      VARCHAR(20);
    DECLARE @cc_code_asignacion VARCHAR(20);
    DECLARE @hay_similares      INT = 0;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = UPPER(LTRIM(RTRIM(ISNULL(@person, ''))));
    SET @name1 = UPPER(LTRIM(RTRIM(ISNULL(@name1, ''))));
    SET @name2 = UPPER(LTRIM(RTRIM(ISNULL(@name2, ''))));
    SET @lastname1 = UPPER(LTRIM(RTRIM(ISNULL(@lastname1, ''))));
    SET @lastname2 = UPPER(LTRIM(RTRIM(ISNULL(@lastname2, ''))));
    SET @birthdate = NULLIF(LTRIM(RTRIM(ISNULL(@birthdate, ''))), '');
    SET @sex = NULLIF(LTRIM(RTRIM(ISNULL(@sex, ''))), '');
    SET @sectelephone = NULLIF(LTRIM(RTRIM(ISNULL(@sectelephone, ''))), '');
    SET @email = NULLIF(LOWER(LTRIM(RTRIM(ISNULL(@email, '')))), '');
    SET @address = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@address, '')))), '');
    SET @nacionalidad = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@nacionalidad, '')))), '');
    SET @employeedocumenttype = LTRIM(RTRIM(ISNULL(@employeedocumenttype, '')));
    SET @documentnumber = LTRIM(RTRIM(ISNULL(@documentnumber, '')));
    SET @replicationunit = UPPER(LTRIM(RTRIM(ISNULL(@replicationunit, ''))));
    SET @userid_norm = NULLIF(LOWER(LTRIM(RTRIM(ISNULL(@userid, '')))), '');
    SET @employeetype = NULLIF(LTRIM(RTRIM(ISNULL(@employeetype, ''))), '');
    SET @employeecategory = NULLIF(LTRIM(RTRIM(ISNULL(@employeecategory, ''))), '');
    SET @entrydate = NULLIF(LTRIM(RTRIM(ISNULL(@entrydate, ''))), '');
    SET @contractmodality = NULLIF(LTRIM(RTRIM(ISNULL(@contractmodality, ''))), '');
    SET @ocupation = NULLIF(LTRIM(RTRIM(ISNULL(@ocupation, ''))), '');
    SET @specialstatus = NULLIF(LTRIM(RTRIM(ISNULL(@specialstatus, ''))), '');
    SET @position = NULLIF(LTRIM(RTRIM(ISNULL(@position, ''))), '');
    SET @costcenter = NULLIF(LTRIM(RTRIM(ISNULL(@costcenter, ''))), '');
    SET @payrolltype = NULLIF(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), '');
    SET @accountprofile = NULLIF(LTRIM(RTRIM(ISNULL(@accountprofile, ''))), '');
    SET @sueldo = NULLIF(LTRIM(RTRIM(ISNULL(@sueldo, ''))), '');
    SET @flagasigfamiliar = CASE WHEN UPPER(ISNULL(@flagasigfamiliar, 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
    SET @pensiontype = NULLIF(LTRIM(RTRIM(ISNULL(@pensiontype, ''))), '');
    SET @pensioninscriptiondate = NULLIF(LTRIM(RTRIM(ISNULL(@pensioninscriptiondate, ''))), '');
    SET @regimehealth = NULLIF(LTRIM(RTRIM(ISNULL(@regimehealth, ''))), '');
    SET @flagmixta = CASE WHEN UPPER(ISNULL(@flagmixta, 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
    SET @cuspp = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@cuspp, '')))), '');
    SET @collectionform = NULLIF(LTRIM(RTRIM(ISNULL(@collectionform, ''))), '');
    SET @salarybank = NULLIF(LTRIM(RTRIM(ISNULL(@salarybank, ''))), '');
    SET @salaryaccounttype = NULLIF(LTRIM(RTRIM(ISNULL(@salaryaccounttype, ''))), '');
    SET @salaryaccount = NULLIF(LTRIM(RTRIM(ISNULL(@salaryaccount, ''))), '');
    SET @cci = NULLIF(LTRIM(RTRIM(ISNULL(@cci, ''))), '');
    SET @ctsbank = NULLIF(LTRIM(RTRIM(ISNULL(@ctsbank, ''))), '');
    SET @ctsaccount = NULLIF(LTRIM(RTRIM(ISNULL(@ctsaccount, ''))), '');
    SET @ctscurrency = CASE WHEN UPPER(ISNULL(@ctscurrency, 'LO')) = 'EX' THEN 'EX' ELSE 'LO' END;
    SET @confirmar_nombre = CASE WHEN UPPER(ISNULL(@confirmar_nombre, 'N')) = 'Y' THEN 'Y' ELSE 'N' END;
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @person_out = NULL;
    SET @mensaje_out = NULL;

    IF @cia = '' OR @person = '' OR @name1 = '' OR @lastname1 = ''
    BEGIN
        RAISERROR('Indique compañía, código, primer nombre y apellido paterno.', 16, 1);
        RETURN;
    END;

    IF @employeedocumenttype = '' OR @documentnumber = ''
    BEGIN
        RAISERROR('Indique tipo y número de documento.', 16, 1);
        RETURN;
    END;

    IF @replicationunit = ''
    BEGIN
        RAISERROR('Indique la unidad.', 16, 1);
        RETURN;
    END;

    IF @sex IS NULL OR @sex NOT IN ('1', '2')
    BEGIN
        RAISERROR('Indique el sexo (1=Masculino, 2=Femenino).', 16, 1);
        RETURN;
    END;

    IF @employeetype IS NULL OR @costcenter IS NULL OR @payrolltype IS NULL OR @entrydate IS NULL
    BEGIN
        RAISERROR('Indique tipo de trabajador, centro de costo, tipo de planilla y fecha de ingreso.', 16, 1);
        RETURN;
    END;

    IF ISDATE(@entrydate) = 0
    BEGIN
        RAISERROR('Fecha de ingreso no válida.', 16, 1);
        RETURN;
    END;
    SET @entrydate_dt = CONVERT(DATETIME, @entrydate, 120);

    SET @birthdate_dt = NULL;
    IF @birthdate IS NOT NULL
    BEGIN
        IF ISDATE(@birthdate) = 0
        BEGIN
            RAISERROR('Fecha de nacimiento no válida.', 16, 1);
            RETURN;
        END;
        SET @birthdate_dt = CONVERT(DATETIME, @birthdate, 120);
    END;

    SET @pensiondate_dt = NULL;
    IF @pensioninscriptiondate IS NOT NULL
    BEGIN
        IF ISDATE(@pensioninscriptiondate) = 0
        BEGIN
            RAISERROR('Fecha de inscripción de pensión no válida.', 16, 1);
            RETURN;
        END;
        SET @pensiondate_dt = CONVERT(DATETIME, @pensioninscriptiondate, 120);
    END;

    IF @sueldo IS NOT NULL
    BEGIN
        SET @rembasica = TRY_CONVERT(NUMERIC(18, 4), REPLACE(@sueldo, ',', ''));
        IF @rembasica IS NULL OR @rembasica < 0
        BEGIN
            RAISERROR('El sueldo indicado no es un valor numérico válido.', 16, 1);
            RETURN;
        END;
    END;

    SET @doc_norm = @documentnumber;
    IF @doc_norm NOT LIKE '%[^0-9]%'
    BEGIN
        WHILE LEN(@doc_norm) > 1 AND LEFT(@doc_norm, 1) = '0'
            SET @doc_norm = SUBSTRING(@doc_norm, 2, 15);
    END;

    IF EXISTS (SELECT 1 FROM SY_Person (NOLOCK) WHERE Person = @person)
    BEGIN
        RAISERROR('El código de trabajador %s ya existe. Use un código distinto.', 16, 1, @person);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Employee e (NOLOCK)
            INNER JOIN SY_Person p (NOLOCK) ON p.Person = e.Person
        WHERE e.Company = @cia
          AND (
                LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) = @documentnumber
             OR LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) = @doc_norm
             OR (
                    ISNUMERIC(p.DocumentNumber) = 1
                AND ISNUMERIC(@doc_norm) = 1
                AND CAST(p.DocumentNumber AS BIGINT) = CAST(@doc_norm AS BIGINT)
             )
          )
    )
    BEGIN
        RAISERROR('El documento %s ya está registrado en esta compañía.', 16, 1, @documentnumber);
        RETURN;
    END;

    SET @nombre_completo = UPPER(LTRIM(RTRIM(
        ISNULL(@lastname1, '') + ' ' +
        ISNULL(@lastname2, '') + ' ' +
        ISNULL(@name1, '') + ' ' +
        ISNULL(@name2, '')
    )));
    WHILE CHARINDEX('  ', @nombre_completo) > 0
        SET @nombre_completo = REPLACE(@nombre_completo, '  ', ' ');
    IF LEN(@nombre_completo) > 100
        SET @nombre_completo = LEFT(@nombre_completo, 100);

    IF @confirmar_nombre <> 'Y'
    BEGIN
        SELECT @hay_similares = COUNT(*)
        FROM SY_Person p (NOLOCK)
        WHERE (
                UPPER(LTRIM(RTRIM(ISNULL(p.LastName1, '')))) = @lastname1
            AND UPPER(LTRIM(RTRIM(ISNULL(p.Name1, '')))) = @name1
          )
           OR UPPER(LTRIM(RTRIM(ISNULL(p.Name, '')))) = @nombre_completo;

        IF @hay_similares > 0
        BEGIN
            RAISERROR('Existen trabajadores con nombre igual o muy parecido. Confirme para continuar.', 16, 1);
            RETURN;
        END;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM SY_PersonDocumentType (NOLOCK)
        WHERE Company = @cia AND PersonDocumentType = @employeedocumenttype
    )
    BEGIN
        RAISERROR('Tipo de documento no válido para la compañía.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM SY_ReplicationUnit (NOLOCK)
        WHERE ReplicationUnit = @replicationunit
    )
    BEGIN
        RAISERROR('Unidad de replicación no válida: %s', 16, 1, @replicationunit);
        RETURN;
    END;

    IF @userid_norm IS NOT NULL
       AND EXISTS (SELECT 1 FROM SY_Person (NOLOCK) WHERE UserID = @userid_norm)
    BEGIN
        RAISERROR('El usuario indicado ya está asignado a otro trabajador.', 16, 1);
        RETURN;
    END;

    SELECT TOP 1 @costcentername = LTRIM(RTRIM(ISNULL(cc.Name, '')))
    FROM AC_CostCenter cc (NOLOCK)
    WHERE cc.Company = @cia
      AND cc.CostCenter = @costcenter;

    SELECT TOP 1 @employee_status_id = es.EmployeeStatus
    FROM PR_EmployeeStatus es (NOLOCK)
    WHERE (es.Company = @cia OR es.EmployeeStatus LIKE 'LIMA' + @cia + '%')
      AND (es.PDT IN ('11', '10') OR UPPER(es.Description) LIKE '%ACTIVO%')
    ORDER BY CASE WHEN es.PDT = '11' THEN 0 WHEN es.PDT = '10' THEN 1 ELSE 2 END,
             CASE WHEN es.EmployeeStatus LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END;

    /* AFP automática desde régimen */
    IF @pensiontype IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM PR_PensionType pt (NOLOCK)
            WHERE pt.PensionType = @pensiontype
              AND (
                    pt.PDT IN ('21', '23', '24', '25')
                 OR (
                        (
                            UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) LIKE '%SPP%'
                         OR UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) LIKE '%AFP%'
                        )
                    AND UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) NOT LIKE '%ONP%'
                 )
              )
        )
            SET @tiene_afp = 'Y';

        SELECT @pension_pdt = LTRIM(RTRIM(ISNULL(pt.PDT, '')))
        FROM PR_PensionType pt (NOLOCK)
        WHERE pt.PensionType = @pensiontype;
    END;

    IF @tiene_afp = 'Y' AND @pension_pdt IN ('21', '23', '24', '25')
    BEGIN
        SELECT TOP 1 @afp_id = a.AFP
        FROM PR_AFP a (NOLOCK)
        WHERE a.Company = @cia
          AND LTRIM(RTRIM(ISNULL(a.PDT, ''))) = @pension_pdt
        ORDER BY
            CASE WHEN a.AFP LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END,
            a.AFP;
    END;

    IF @salaryaccounttype IS NULL
        SELECT TOP 1 @salaryaccounttype = e.SalaryAccountType
        FROM PR_Employee e (NOLOCK)
        WHERE e.Company = @cia AND e.SalaryAccountType IS NOT NULL
        ORDER BY e.XLastDate DESC;

    IF @accountprofile IS NULL
        SELECT TOP 1 @accountprofile = e.AccountProfile
        FROM PR_Employee e (NOLOCK)
        WHERE e.Company = @cia
          AND e.EmployeeType = @employeetype
          AND e.AccountProfile IS NOT NULL
        ORDER BY e.XLastDate DESC;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO SY_Person (
            Person, FlagUserID, PersonType, Name, Address,
            DocumentType, DocumentNumber, Email, Status, FlagRucPersonType,
            IsVendor, IsCustomer, XLastUser, XLastDate, Company,
            ReplicationUnit, IsEmployee, SecTelephone, Name2, LastName1,
            Name1, LastName2, BirthDate, Sex,
            EmployeeDocumentType, FlagKeep, FlagName, FlagOutsourcingIn,
            FlagOutsourcingOut, IsDomiciled, Nacionalidad, FlagPerceptionAgent,
            FlagSunat5, IsTrainer, IsRecruiter, IsSupervisor, Indicator,
            FlagLockCA, LicenseCondition, UserID
        )
        VALUES (
            @person, 'N', 'NN', @nombre_completo, @address,
            @employeedocumenttype, @documentnumber, @email, 'A', 'XX',
            'Y', 'N', @xlastuser, GETDATE(), @cia,
            @replicationunit, 'Y', @sectelephone, NULLIF(@name2, ''), @lastname1,
            @name1, NULLIF(@lastname2, ''), @birthdate_dt, @sex,
            @employeedocumenttype, 'N', 'P', 'N',
            'N', '1', @nacionalidad, 'N',
            'N', 'N', 'N', 'N', NULL,
            'N', 'L', @userid_norm
        );

        INSERT INTO PR_Employee (
            Person, Company, EmployeeCode, EmployeeType, EmployeeCategory,
            EntryDate, ReEntryDate, PensionType, PensionInscriptionDate,
            SalaryBank, SalaryAccountType, SalaryCurrency, SalaryAccount,
            CostCenter, Position, AccountProfile, PayRollType, EmployeeStatus,
            FlagEssaludVida, Status, XLastDate, XLastUser, ReplicationUnit,
            CostCenterName, FlagDistribution, ContractModality, ConsiderInCalc,
            FlagParticipar, FlagAsigFamiliar,
            SpecialStatus, CollectionForm, Ocupation, RegimeHealth,
            RemBasica, Salary, AFPCard, FlagMixta, AFP,
            CTSBank, CTSAccount, CTSCurrency, SocialAssistanceNumber
        )
        VALUES (
            @person, @cia, @person, @employeetype, @employeecategory,
            @entrydate_dt, @entrydate_dt, @pensiontype, @pensiondate_dt,
            @salarybank, @salaryaccounttype, 'LO', @salaryaccount,
            @costcenter, @position, @accountprofile, @payrolltype, @employee_status_id,
            'N', 'N', GETDATE(), @xlastuser, @replicationunit,
            NULLIF(@costcentername, ''), 'H', @contractmodality, 'Y',
            'Y', @flagasigfamiliar,
            @specialstatus, @collectionform, @ocupation, @regimehealth,
            @rembasica, @rembasica, @cuspp, @flagmixta, @afp_id,
            @ctsbank, @ctsaccount, @ctscurrency, @cci
        );

        /* Construcción Civil: no asignar REM_BASICA */
        IF EXISTS (
            SELECT 1 FROM PR_EmployeeType et (NOLOCK)
            WHERE et.EmployeeType = @employeetype
              AND (
                    et.PDT = '27'
                 OR UPPER(LTRIM(RTRIM(ISNULL(et.Description, '')))) LIKE '%CONSTRUCCION%'
              )
        )
            SET @es_construccion = 'Y';

        IF @es_construccion = 'N' AND EXISTS (
            SELECT 1 FROM PR_PayRollType pt (NOLOCK)
            WHERE pt.PayRollType = @payrolltype
              AND (
                    UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) LIKE '%CONSTRUCCION%'
                 OR UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) LIKE '%CONSTRUCCION%'
              )
        )
            SET @es_construccion = 'Y';

        SET @period_start = NULL;
        SELECT TOP 1 @period_start = p.PRPeriod
        FROM PR_Period p (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype
          AND @entrydate_dt BETWEEN p.DateBegin AND p.DateEnd
        ORDER BY p.PRPeriod;

        IF @period_start IS NULL
        BEGIN
            SELECT TOP 1 @period_start = p.PRPeriod
            FROM PR_Period p (NOLOCK)
            WHERE p.Company = @cia
              AND p.PayRollType = @payrolltype
              AND p.DateBegin >= @entrydate_dt
            ORDER BY p.DateBegin ASC, p.PRPeriod ASC;

            IF @period_start IS NULL
                SELECT TOP 1 @period_start = p.PRPeriod
                FROM PR_Period p (NOLOCK)
                WHERE p.Company = @cia
                  AND p.PayRollType = @payrolltype
                  AND p.DateBegin <= @entrydate_dt
                ORDER BY p.DateBegin DESC, p.PRPeriod DESC;
        END;

        SET @cc_asignacion = ISNULL(@costcenter, '');
        SET @cc_code_asignacion = ISNULL(NULLIF(@costcentername, ''), @cc_asignacion);

        IF @es_construccion = 'N'
           AND @rembasica IS NOT NULL
           AND @rembasica > 0
           AND @period_start IS NOT NULL
        BEGIN
            SELECT TOP 1 @concept_rembasica = c.Concept
            FROM PR_Concept c (NOLOCK)
            WHERE c.Company = @cia
              AND c.FormulaCode = 'REM_BASICA'
              AND c.Status = 'A'
            ORDER BY c.Concept;

            IF @concept_rembasica IS NOT NULL
            BEGIN
                INSERT INTO PR_EmployeeConcept (
                    Person, Company, Concept, PayRollType, PRPeriodStart, CostCenter,
                    PRPeriodEnd, ConceptValue, Application, ConceptCurrency, Comments,
                    FlagApplyFormula, FlagFrecuencyType, ReplicationUnit,
                    XLastUser, XLastDate, ConceptValueLo, ConceptValueEx, ExchangeRate,
                    CostCenterCode, Project, ProjectCode, PercentageDistribution, FlagCopy
                )
                VALUES (
                    @person, @cia, @concept_rembasica, @payrolltype, @period_start, @cc_asignacion,
                    NULL, @rembasica, NULL, 'LO', NULL,
                    'N', 'P', @replicationunit,
                    @xlastuser, GETDATE(), @rembasica, 0, 0,
                    @cc_code_asignacion, '', '', 'A', NULL
                );
            END;
        END;

        IF @tiene_afp = 'Y' AND @period_start IS NOT NULL
        BEGIN
            SELECT TOP 1 @concept_afp_flujo = c.Concept
            FROM PR_Concept c (NOLOCK)
            WHERE c.Company = @cia
              AND c.FormulaCode = 'AFP_FLUJO'
              AND c.Status = 'A'
            ORDER BY c.Concept;

            IF @concept_afp_flujo IS NOT NULL
            BEGIN
                INSERT INTO PR_EmployeeConcept (
                    Person, Company, Concept, PayRollType, PRPeriodStart, CostCenter,
                    PRPeriodEnd, ConceptValue, Application, ConceptCurrency, Comments,
                    FlagApplyFormula, FlagFrecuencyType, ReplicationUnit,
                    XLastUser, XLastDate, ConceptValueLo, ConceptValueEx, ExchangeRate,
                    CostCenterCode, Project, ProjectCode, PercentageDistribution, FlagCopy
                )
                VALUES (
                    @person, @cia, @concept_afp_flujo, @payrolltype, @period_start, @cc_asignacion,
                    NULL, 1, NULL, 'LO', NULL,
                    'N', 'P', @replicationunit,
                    @xlastuser, GETDATE(), 1, 0, 0,
                    @cc_code_asignacion, '', '', 'A', NULL
                );
            END;
        END;

        COMMIT TRANSACTION;
        SET @person_out = @person;
        SET @mensaje_out = 'Trabajador registrado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('%s', 16, 1, @err);
        RETURN;
    END CATCH
END
GO
