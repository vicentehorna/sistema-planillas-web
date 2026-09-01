/*
    Traslado de trabajador cesado a otra empresa (misma BD).

    - Mantiene SY_Person (no modifica SY_Person.Company).
    - Crea nuevo PR_Employee en @cia_destino con EntryDate/ReEntryDate = @entrydate.
    - Copia campos equivalentes mapeando catálogos por PDT / ShortName / descripción.
    - Copia asignaciones permanentes (PR_EmployeeConcept, FlagFrecuencyType = 'P')
      mapeando concepto por FormulaCode y planilla por ShortName.

    Validaciones:
      - Trabajador cesado en origen.
      - No existe PR_Employee en destino para el mismo Person.
      - @entrydate > CeaseDate origen.
      - @cia_origen <> @cia_destino.

    Usado por: POST /api/trabajadores/trasladar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_trasladar_trabajador_web]
    @cia_origen     VARCHAR(10),
    @cia_destino    VARCHAR(10),
    @person         VARCHAR(20),
    @entrydate      VARCHAR(10),
    @xlastuser      VARCHAR(20) = NULL,
    @mensaje_out    VARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia_origen = LTRIM(RTRIM(ISNULL(@cia_origen, '')));
    SET @cia_destino = LTRIM(RTRIM(ISNULL(@cia_destino, '')));
    SET @person = UPPER(LTRIM(RTRIM(ISNULL(@person, ''))));
    SET @entrydate = NULLIF(LTRIM(RTRIM(ISNULL(@entrydate, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @mensaje_out = NULL;

    IF @cia_origen = '' OR @cia_destino = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía origen, compañía destino y trabajador.', 16, 1);
        RETURN;
    END;

    IF @cia_origen = @cia_destino
    BEGIN
        RAISERROR('La empresa destino debe ser distinta a la empresa actual.', 16, 1);
        RETURN;
    END;

    IF @entrydate IS NULL OR ISDATE(@entrydate) = 0
    BEGIN
        RAISERROR('Indique una fecha de ingreso válida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM SY_Person (NOLOCK) WHERE Person = @person)
    BEGIN
        RAISERROR('El trabajador no existe en SY_Person.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Employee e (NOLOCK)
        WHERE e.Company = @cia_origen
          AND e.Person = @person
    )
    BEGIN
        RAISERROR('El trabajador no existe en la empresa origen.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Employee e (NOLOCK)
        WHERE e.Company = @cia_destino
          AND e.Person = @person
    )
    BEGIN
        RAISERROR('El trabajador ya está registrado en la empresa destino.', 16, 1);
        RETURN;
    END;

    DECLARE @entrydate_dt DATETIME = CONVERT(DATETIME, @entrydate, 120);
    DECLARE @cese_origen DATETIME = NULL;

    SELECT @cese_origen = e.CeaseDate
    FROM PR_Employee e (NOLOCK)
    WHERE e.Company = @cia_origen
      AND e.Person = @person;

    IF @cese_origen IS NULL
    BEGIN
        RAISERROR('Solo se puede trasladar un trabajador cesado.', 16, 1);
        RETURN;
    END;

    IF CONVERT(DATE, @entrydate_dt) <= CONVERT(DATE, @cese_origen)
    BEGIN
        RAISERROR('La fecha de ingreso en la nueva empresa debe ser posterior a la fecha de cese.', 16, 1);
        RETURN;
    END;

    DECLARE
        @employeetype           VARCHAR(20) = NULL,
        @employeecategory       VARCHAR(20) = NULL,
        @contractmodality       VARCHAR(20) = NULL,
        @ocupation              VARCHAR(20) = NULL,
        @specialstatus          VARCHAR(20) = NULL,
        @position               VARCHAR(20) = NULL,
        @costcenter             VARCHAR(20) = NULL,
        @costcentername         VARCHAR(20) = NULL,
        @payrolltype            VARCHAR(20) = NULL,
        @accountprofile         VARCHAR(20) = NULL,
        @pensiontype            VARCHAR(20) = NULL,
        @pensioninscriptiondate DATETIME = NULL,
        @regimehealth           VARCHAR(20) = NULL,
        @flagmixta              CHAR(1) = 'N',
        @flagasigfamiliar       CHAR(1) = 'N',
        @cuspp                  VARCHAR(20) = NULL,
        @collectionform         VARCHAR(20) = NULL,
        @salarybank             VARCHAR(20) = NULL,
        @salaryaccounttype      VARCHAR(20) = NULL,
        @salaryaccount          VARCHAR(20) = NULL,
        @cci                    VARCHAR(20) = NULL,
        @ctsbank                VARCHAR(20) = NULL,
        @ctsaccount             VARCHAR(20) = NULL,
        @ctscurrency            CHAR(2) = 'LO',
        @rembasica              NUMERIC(18, 4) = NULL,
        @afp_id                 VARCHAR(20) = NULL,
        @replicationunit        VARCHAR(4) = NULL,
        @employee_status_id     VARCHAR(20) = NULL,
        @flagdistribution       CHAR(1) = 'H',
        @considerincalc         CHAR(1) = 'Y',
        @flagparticipar         CHAR(1) = 'Y',
        @flagessaludvida        CHAR(1) = 'N',
        @period_start           VARCHAR(10) = NULL,
        @cc_asignacion          VARCHAR(20) = NULL,
        @cc_code_asignacion     VARCHAR(20) = NULL;

    SELECT
        @employeetype = NULLIF(LTRIM(RTRIM(e.EmployeeType)), ''),
        @employeecategory = NULLIF(LTRIM(RTRIM(e.EmployeeCategory)), ''),
        @contractmodality = NULLIF(LTRIM(RTRIM(e.ContractModality)), ''),
        @ocupation = NULLIF(LTRIM(RTRIM(e.Ocupation)), ''),
        @specialstatus = NULLIF(LTRIM(RTRIM(e.SpecialStatus)), ''),
        @position = NULLIF(LTRIM(RTRIM(e.Position)), ''),
        @costcenter = NULLIF(LTRIM(RTRIM(e.CostCenter)), ''),
        @costcentername = NULLIF(LTRIM(RTRIM(e.CostCenterName)), ''),
        @payrolltype = NULLIF(LTRIM(RTRIM(e.PayRollType)), ''),
        @accountprofile = NULLIF(LTRIM(RTRIM(e.AccountProfile)), ''),
        @pensiontype = NULLIF(LTRIM(RTRIM(e.PensionType)), ''),
        @pensioninscriptiondate = e.PensionInscriptionDate,
        @regimehealth = NULLIF(LTRIM(RTRIM(e.RegimeHealth)), ''),
        @flagmixta = CASE WHEN UPPER(ISNULL(e.FlagMixta, 'N')) = 'Y' THEN 'Y' ELSE 'N' END,
        @flagasigfamiliar = CASE WHEN UPPER(ISNULL(e.FlagAsigFamiliar, 'N')) = 'Y' THEN 'Y' ELSE 'N' END,
        @cuspp = NULLIF(LTRIM(RTRIM(e.AFPCard)), ''),
        @collectionform = NULLIF(LTRIM(RTRIM(e.CollectionForm)), ''),
        @salarybank = NULLIF(LTRIM(RTRIM(e.SalaryBank)), ''),
        @salaryaccounttype = NULLIF(LTRIM(RTRIM(e.SalaryAccountType)), ''),
        @salaryaccount = NULLIF(LTRIM(RTRIM(e.SalaryAccount)), ''),
        @cci = NULLIF(LTRIM(RTRIM(e.SocialAssistanceNumber)), ''),
        @ctsbank = NULLIF(LTRIM(RTRIM(e.CTSBank)), ''),
        @ctsaccount = NULLIF(LTRIM(RTRIM(e.CTSAccount)), ''),
        @ctscurrency = CASE WHEN UPPER(ISNULL(e.CTSCurrency, 'LO')) = 'EX' THEN 'EX' ELSE 'LO' END,
        @rembasica = COALESCE(e.RemBasica, e.Salary),
        @afp_id = NULLIF(LTRIM(RTRIM(e.AFP)), ''),
        @replicationunit = NULLIF(LTRIM(RTRIM(e.ReplicationUnit)), ''),
        @flagdistribution = CASE WHEN UPPER(ISNULL(e.FlagDistribution, 'H')) = 'H' THEN 'H' ELSE ISNULL(e.FlagDistribution, 'H') END,
        @considerincalc = CASE WHEN UPPER(ISNULL(e.ConsiderInCalc, 'Y')) = 'N' THEN 'N' ELSE 'Y' END,
        @flagparticipar = CASE WHEN UPPER(ISNULL(e.FlagParticipar, 'Y')) = 'N' THEN 'N' ELSE 'Y' END,
        @flagessaludvida = CASE WHEN UPPER(ISNULL(e.FlagEssaludVida, 'N')) = 'Y' THEN 'Y' ELSE 'N' END
    FROM PR_Employee e (NOLOCK)
    WHERE e.Company = @cia_origen
      AND e.Person = @person;

    IF @replicationunit IS NULL
    BEGIN
        SELECT @replicationunit = NULLIF(LTRIM(RTRIM(sp.ReplicationUnit)), '')
        FROM SY_Person sp (NOLOCK)
        WHERE sp.Person = @person;
    END;

    IF @employeetype IS NOT NULL
    BEGIN
        SELECT TOP 1 @employeetype = t2.EmployeeType
        FROM PR_EmployeeType t1 (NOLOCK)
            INNER JOIN PR_EmployeeType t2 (NOLOCK)
                ON t2.Company = @cia_destino
               AND (
                    (
                        NULLIF(LTRIM(RTRIM(ISNULL(t1.PDT, ''))), '') IS NOT NULL
                        AND LTRIM(RTRIM(ISNULL(t2.PDT, ''))) = LTRIM(RTRIM(ISNULL(t1.PDT, '')))
                    )
                    OR UPPER(LTRIM(RTRIM(ISNULL(t2.Description, ''))))
                       = UPPER(LTRIM(RTRIM(ISNULL(t1.Description, ''))))
               )
        WHERE t1.Company = @cia_origen
          AND t1.EmployeeType = @employeetype
        ORDER BY
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(t1.PDT, ''))), '') IS NOT NULL
                 AND LTRIM(RTRIM(ISNULL(t2.PDT, ''))) = LTRIM(RTRIM(ISNULL(t1.PDT, '')))
                    THEN 0 ELSE 1
            END,
            t2.EmployeeType;
    END;

    IF @employeecategory IS NOT NULL
    BEGIN
        SELECT TOP 1 @employeecategory = c2.EmployeeCategory
        FROM PR_EmployeeCategory c1 (NOLOCK)
            INNER JOIN PR_EmployeeCategory c2 (NOLOCK)
                ON c2.Company = @cia_destino
               AND UPPER(LTRIM(RTRIM(ISNULL(c2.Description, ''))))
                   = UPPER(LTRIM(RTRIM(ISNULL(c1.Description, ''))))
        WHERE c1.Company = @cia_origen
          AND c1.EmployeeCategory = @employeecategory
        ORDER BY c2.EmployeeCategory;
    END;

    IF @contractmodality IS NOT NULL
    BEGIN
        SELECT TOP 1 @contractmodality = m2.ContractModality
        FROM HR_ContractModality m1 (NOLOCK)
            INNER JOIN HR_ContractModality m2 (NOLOCK)
                ON m2.Company = @cia_destino
               AND UPPER(LTRIM(RTRIM(ISNULL(m2.Description, ''))))
                   = UPPER(LTRIM(RTRIM(ISNULL(m1.Description, ''))))
        WHERE m1.Company = @cia_origen
          AND m1.ContractModality = @contractmodality
        ORDER BY m2.ContractModality;
    END;

    IF @ocupation IS NOT NULL
    BEGIN
        SELECT TOP 1 @ocupation = o2.Ocupation
        FROM PR_Ocupation o1 (NOLOCK)
            INNER JOIN PR_Ocupation o2 (NOLOCK)
                ON o2.Company = @cia_destino
               AND UPPER(LTRIM(RTRIM(ISNULL(o2.Description, ''))))
                   = UPPER(LTRIM(RTRIM(ISNULL(o1.Description, ''))))
        WHERE o1.Company = @cia_origen
          AND o1.Ocupation = @ocupation
        ORDER BY o2.Ocupation;
    END;

    IF @specialstatus IS NOT NULL
    BEGIN
        SELECT TOP 1 @specialstatus = s2.SpecialStatus
        FROM PR_SpecialStatus s1 (NOLOCK)
            INNER JOIN PR_SpecialStatus s2 (NOLOCK)
                ON s2.Company = @cia_destino
               AND UPPER(LTRIM(RTRIM(ISNULL(s2.Description, ''))))
                   = UPPER(LTRIM(RTRIM(ISNULL(s1.Description, ''))))
        WHERE s1.Company = @cia_origen
          AND s1.SpecialStatus = @specialstatus
        ORDER BY s2.SpecialStatus;
    END;

    IF @position IS NOT NULL
    BEGIN
        SELECT TOP 1 @position = p2.Position
        FROM PR_Position p1 (NOLOCK)
            INNER JOIN PR_Position p2 (NOLOCK)
                ON p2.Company = @cia_destino
               AND (
                    UPPER(LTRIM(RTRIM(ISNULL(p2.Name, ''))))
                        = UPPER(LTRIM(RTRIM(ISNULL(p1.Name, ''))))
                    OR UPPER(LTRIM(RTRIM(ISNULL(p2.Description, ''))))
                        = UPPER(LTRIM(RTRIM(ISNULL(p1.Description, ''))))
               )
        WHERE p1.Company = @cia_origen
          AND p1.Position = @position
        ORDER BY
            CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(p2.Name, ''))))
                     = UPPER(LTRIM(RTRIM(ISNULL(p1.Name, ''))))
                    THEN 0 ELSE 1
            END,
            p2.Position;
    END;

    IF @costcenter IS NOT NULL
    BEGIN
        SELECT TOP 1
            @costcenter = cc2.CostCenter,
            @costcentername = NULLIF(LTRIM(RTRIM(ISNULL(cc2.Name, ''))), '')
        FROM AC_CostCenter cc1 (NOLOCK)
            INNER JOIN AC_CostCenter cc2 (NOLOCK)
                ON cc2.Company = @cia_destino
               AND (
                    (
                        NULLIF(LTRIM(RTRIM(ISNULL(cc1.Abbrev, ''))), '') IS NOT NULL
                        AND LTRIM(RTRIM(ISNULL(cc2.Abbrev, ''))) = LTRIM(RTRIM(ISNULL(cc1.Abbrev, '')))
                    )
                    OR UPPER(LTRIM(RTRIM(ISNULL(cc2.Name, ''))))
                       = UPPER(LTRIM(RTRIM(ISNULL(cc1.Name, ''))))
                    OR UPPER(LTRIM(RTRIM(ISNULL(cc2.Description, ''))))
                       = UPPER(LTRIM(RTRIM(ISNULL(cc1.Description, ''))))
               )
        WHERE cc1.Company = @cia_origen
          AND cc1.CostCenter = @costcenter
        ORDER BY
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(cc1.Abbrev, ''))), '') IS NOT NULL
                 AND LTRIM(RTRIM(ISNULL(cc2.Abbrev, ''))) = LTRIM(RTRIM(ISNULL(cc1.Abbrev, '')))
                    THEN 0 ELSE 1
            END,
            cc2.CostCenter;
    END;

    IF @payrolltype IS NOT NULL
    BEGIN
        SELECT TOP 1 @payrolltype = pt2.PayRollType
        FROM PR_PayRollType pt1 (NOLOCK)
            INNER JOIN PR_PayRollType pt2 (NOLOCK)
                ON pt2.Company = @cia_destino
               AND LTRIM(RTRIM(ISNULL(pt2.ShortName, ''))) = LTRIM(RTRIM(ISNULL(pt1.ShortName, '')))
        WHERE pt1.Company = @cia_origen
          AND pt1.PayRollType = @payrolltype
        ORDER BY pt2.PayRollType;
    END;

    IF @accountprofile IS NOT NULL
    BEGIN
        SELECT TOP 1 @accountprofile = a2.AccountProfile
        FROM PR_AccountProfile a1 (NOLOCK)
            INNER JOIN PR_AccountProfile a2 (NOLOCK)
                ON a2.Company = @cia_destino
               AND UPPER(LTRIM(RTRIM(ISNULL(a2.Description, ''))))
                   = UPPER(LTRIM(RTRIM(ISNULL(a1.Description, ''))))
        WHERE a1.Company = @cia_origen
          AND a1.AccountProfile = @accountprofile
        ORDER BY a2.AccountProfile;
    END;

    IF @pensiontype IS NOT NULL
    BEGIN
        SELECT TOP 1 @pensiontype = pt2.PensionType
        FROM PR_PensionType pt1 (NOLOCK)
            INNER JOIN PR_PensionType pt2 (NOLOCK)
                ON (
                    LTRIM(RTRIM(ISNULL(pt2.Company, ''))) = ''
                    OR pt2.Company = @cia_destino
                )
               AND (
                    (
                        NULLIF(LTRIM(RTRIM(ISNULL(pt1.PDT, ''))), '') IS NOT NULL
                        AND LTRIM(RTRIM(ISNULL(pt2.PDT, ''))) = LTRIM(RTRIM(ISNULL(pt1.PDT, '')))
                    )
                    OR UPPER(LTRIM(RTRIM(ISNULL(pt2.Description, ''))))
                       = UPPER(LTRIM(RTRIM(ISNULL(pt1.Description, ''))))
               )
        WHERE pt1.PensionType = @pensiontype
          AND (
                LTRIM(RTRIM(ISNULL(pt1.Company, ''))) = ''
                OR pt1.Company = @cia_origen
          )
        ORDER BY
            CASE WHEN pt2.Company = @cia_destino THEN 0 ELSE 1 END,
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(pt1.PDT, ''))), '') IS NOT NULL
                 AND LTRIM(RTRIM(ISNULL(pt2.PDT, ''))) = LTRIM(RTRIM(ISNULL(pt1.PDT, '')))
                    THEN 0 ELSE 1
            END,
            pt2.PensionType;
    END;

    IF @regimehealth IS NOT NULL
    BEGIN
        SELECT TOP 1 @regimehealth = rh2.RegimeHealth
        FROM PR_RegimeHealth rh1 (NOLOCK)
            INNER JOIN PR_RegimeHealth rh2 (NOLOCK)
                ON (
                    LTRIM(RTRIM(ISNULL(rh2.Company, ''))) = ''
                    OR rh2.Company = @cia_destino
                )
               AND (
                    (
                        NULLIF(LTRIM(RTRIM(ISNULL(rh1.PDT, ''))), '') IS NOT NULL
                        AND LTRIM(RTRIM(ISNULL(rh2.PDT, ''))) = LTRIM(RTRIM(ISNULL(rh1.PDT, '')))
                    )
                    OR UPPER(LTRIM(RTRIM(ISNULL(rh2.Description, ''))))
                       = UPPER(LTRIM(RTRIM(ISNULL(rh1.Description, ''))))
               )
        WHERE rh1.RegimeHealth = @regimehealth
          AND (
                LTRIM(RTRIM(ISNULL(rh1.Company, ''))) = ''
                OR rh1.Company = @cia_origen
          )
        ORDER BY
            CASE WHEN rh2.Company = @cia_destino THEN 0 ELSE 1 END,
            rh2.RegimeHealth;
    END;

    IF @afp_id IS NOT NULL
    BEGIN
        SELECT TOP 1 @afp_id = a2.AFP
        FROM PR_AFP a1 (NOLOCK)
            INNER JOIN PR_AFP a2 (NOLOCK)
                ON a2.Company = @cia_destino
               AND LTRIM(RTRIM(ISNULL(a2.PDT, ''))) = LTRIM(RTRIM(ISNULL(a1.PDT, '')))
        WHERE a1.Company = @cia_origen
          AND a1.AFP = @afp_id
        ORDER BY
            CASE WHEN a2.AFP LIKE 'LIMA' + @cia_destino + '%' THEN 0 ELSE 1 END,
            a2.AFP;
    END;

    IF @collectionform IS NOT NULL
       AND NOT EXISTS (
            SELECT 1 FROM TE_CollectionForm (NOLOCK)
            WHERE CollectionForm = @collectionform
       )
        SET @collectionform = NULL;

    IF @salaryaccounttype IS NOT NULL
       AND NOT EXISTS (
            SELECT 1 FROM TE_AccountType (NOLOCK)
            WHERE AccountType = @salaryaccounttype
       )
        SET @salaryaccounttype = NULL;

    IF @salarybank IS NOT NULL
    BEGIN
        SELECT TOP 1 @salarybank = b2.Bank
        FROM ERP_Bank b1 (NOLOCK)
            INNER JOIN ERP_Bank b2 (NOLOCK)
                ON b2.Company = @cia_destino
               AND UPPER(LTRIM(RTRIM(ISNULL(b2.Name, ''))))
                   = UPPER(LTRIM(RTRIM(ISNULL(b1.Name, ''))))
        WHERE b1.Company = @cia_origen
          AND b1.Bank = @salarybank
        ORDER BY b2.Bank;
    END;

    IF @ctsbank IS NOT NULL
    BEGIN
        SELECT TOP 1 @ctsbank = b2.Bank
        FROM ERP_Bank b1 (NOLOCK)
            INNER JOIN ERP_Bank b2 (NOLOCK)
                ON b2.Company = @cia_destino
               AND UPPER(LTRIM(RTRIM(ISNULL(b2.Name, ''))))
                   = UPPER(LTRIM(RTRIM(ISNULL(b1.Name, ''))))
        WHERE b1.Company = @cia_origen
          AND b1.Bank = @ctsbank
        ORDER BY b2.Bank;
    END;

    SELECT TOP 1 @employee_status_id = es.EmployeeStatus
    FROM PR_EmployeeStatus es (NOLOCK)
    WHERE (es.Company = @cia_destino OR es.EmployeeStatus LIKE 'LIMA' + @cia_destino + '%')
      AND (es.PDT IN ('11', '10') OR UPPER(es.Description) LIKE '%ACTIVO%')
    ORDER BY
        CASE WHEN es.PDT = '11' THEN 0 WHEN es.PDT = '10' THEN 1 ELSE 2 END,
        CASE WHEN es.EmployeeStatus LIKE 'LIMA' + @cia_destino + '%' THEN 0 ELSE 1 END;

    IF @payrolltype IS NOT NULL
    BEGIN
        SELECT TOP 1 @period_start = p.PRPeriod
        FROM PR_Period p (NOLOCK)
        WHERE p.Company = @cia_destino
          AND p.PayRollType = @payrolltype
          AND @entrydate_dt BETWEEN p.DateBegin AND p.DateEnd
        ORDER BY p.PRPeriod;

        IF @period_start IS NULL
        BEGIN
            SELECT TOP 1 @period_start = p.PRPeriod
            FROM PR_Period p (NOLOCK)
            WHERE p.Company = @cia_destino
              AND p.PayRollType = @payrolltype
              AND p.DateBegin >= @entrydate_dt
            ORDER BY p.DateBegin ASC, p.PRPeriod ASC;

            IF @period_start IS NULL
                SELECT TOP 1 @period_start = p.PRPeriod
                FROM PR_Period p (NOLOCK)
                WHERE p.Company = @cia_destino
                  AND p.PayRollType = @payrolltype
                  AND p.DateBegin <= @entrydate_dt
                ORDER BY p.DateBegin DESC, p.PRPeriod DESC;
        END;
    END;

    SET @cc_asignacion = ISNULL(@costcenter, '');
    SET @cc_code_asignacion = ISNULL(NULLIF(@costcentername, ''), @cc_asignacion);

    BEGIN TRY
        BEGIN TRANSACTION;

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
            CTSBank, CTSAccount, CTSCurrency, SocialAssistanceNumber,
            CeaseDate, CeaseReason
        )
        VALUES (
            @person, @cia_destino, @person, @employeetype, @employeecategory,
            @entrydate_dt, @entrydate_dt, @pensiontype, @pensioninscriptiondate,
            @salarybank, @salaryaccounttype, 'LO', @salaryaccount,
            @costcenter, @position, @accountprofile, @payrolltype, @employee_status_id,
            @flagessaludvida, 'N', GETDATE(), @xlastuser, @replicationunit,
            @costcentername, @flagdistribution, @contractmodality, @considerincalc,
            @flagparticipar, @flagasigfamiliar,
            @specialstatus, @collectionform, @ocupation, @regimehealth,
            @rembasica, @rembasica, @cuspp, @flagmixta, @afp_id,
            @ctsbank, @ctsaccount, @ctscurrency, @cci,
            NULL, NULL
        );

        IF @period_start IS NOT NULL
        BEGIN
            INSERT INTO PR_EmployeeConcept (
                Person, Company, Concept, PayRollType, PRPeriodStart, CostCenter,
                PRPeriodEnd, ConceptValue, Application, ConceptCurrency, Comments,
                FlagApplyFormula, FlagFrecuencyType, ReplicationUnit,
                XLastUser, XLastDate, ConceptValueLo, ConceptValueEx, ExchangeRate,
                CostCenterCode, Project, ProjectCode, PercentageDistribution, FlagCopy
            )
            SELECT
                ec.Person,
                @cia_destino,
                c_dest.Concept,
                pt_dest.PayRollType,
                @period_start,
                ISNULL(cc_dest.CostCenter, @cc_asignacion),
                NULL,
                ec.ConceptValue,
                ec.Application,
                ISNULL(ec.ConceptCurrency, 'LO'),
                ec.Comments,
                ISNULL(ec.FlagApplyFormula, 'N'),
                ec.FlagFrecuencyType,
                ISNULL(@replicationunit, ec.ReplicationUnit),
                @xlastuser,
                GETDATE(),
                ec.ConceptValueLo,
                ISNULL(ec.ConceptValueEx, 0),
                ISNULL(ec.ExchangeRate, 0),
                ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(cc_dest.Name, ''))), ''), @cc_code_asignacion),
                ISNULL(ec.Project, ''),
                ISNULL(ec.ProjectCode, ''),
                ISNULL(ec.PercentageDistribution, 'A'),
                ec.FlagCopy
            FROM PR_EmployeeConcept ec (NOLOCK)
                INNER JOIN PR_Concept c_orig (NOLOCK)
                    ON c_orig.Company = ec.Company
                   AND c_orig.Concept = ec.Concept
                INNER JOIN PR_Concept c_dest (NOLOCK)
                    ON c_dest.Company = @cia_destino
                   AND LTRIM(RTRIM(ISNULL(c_dest.FormulaCode, ''))) = LTRIM(RTRIM(ISNULL(c_orig.FormulaCode, '')))
                   AND UPPER(ISNULL(c_dest.Status, 'A')) = 'A'
                INNER JOIN PR_PayRollType pt_orig (NOLOCK)
                    ON pt_orig.PayRollType = ec.PayRollType
                INNER JOIN PR_PayRollType pt_dest (NOLOCK)
                    ON pt_dest.Company = @cia_destino
                   AND LTRIM(RTRIM(ISNULL(pt_dest.ShortName, ''))) = LTRIM(RTRIM(ISNULL(pt_orig.ShortName, '')))
                LEFT JOIN AC_CostCenter cc_orig (NOLOCK)
                    ON cc_orig.Company = ec.Company
                   AND cc_orig.CostCenter = ec.CostCenter
                OUTER APPLY (
                    SELECT TOP 1
                        cc2.CostCenter,
                        cc2.Name
                    FROM AC_CostCenter cc2 (NOLOCK)
                    WHERE cc_orig.CostCenter IS NOT NULL
                      AND cc2.Company = @cia_destino
                      AND (
                            (
                                NULLIF(LTRIM(RTRIM(ISNULL(cc_orig.Abbrev, ''))), '') IS NOT NULL
                                AND LTRIM(RTRIM(ISNULL(cc2.Abbrev, ''))) = LTRIM(RTRIM(ISNULL(cc_orig.Abbrev, '')))
                            )
                            OR UPPER(LTRIM(RTRIM(ISNULL(cc2.Name, ''))))
                               = UPPER(LTRIM(RTRIM(ISNULL(cc_orig.Name, ''))))
                            OR UPPER(LTRIM(RTRIM(ISNULL(cc2.Description, ''))))
                               = UPPER(LTRIM(RTRIM(ISNULL(cc_orig.Description, ''))))
                      )
                    ORDER BY
                        CASE
                            WHEN NULLIF(LTRIM(RTRIM(ISNULL(cc_orig.Abbrev, ''))), '') IS NOT NULL
                             AND LTRIM(RTRIM(ISNULL(cc2.Abbrev, ''))) = LTRIM(RTRIM(ISNULL(cc_orig.Abbrev, '')))
                                THEN 0 ELSE 1
                        END,
                        cc2.CostCenter
                ) cc_dest
            WHERE ec.Company = @cia_origen
              AND ec.Person = @person
              AND ec.FlagFrecuencyType = 'P'
              AND ec.PRPeriodEnd IS NULL
              AND NULLIF(LTRIM(RTRIM(ISNULL(c_orig.FormulaCode, ''))), '') IS NOT NULL
              AND NOT EXISTS (
                    SELECT 1
                    FROM PR_EmployeeConcept ec2 (NOLOCK)
                    WHERE ec2.Company = @cia_destino
                      AND ec2.Person = ec.Person
                      AND ec2.Concept = c_dest.Concept
                      AND ec2.PayRollType = pt_dest.PayRollType
                      AND ec2.FlagFrecuencyType = 'P'
                      AND ec2.PRPeriodEnd IS NULL
              );
        END;

        COMMIT TRANSACTION;
        SET @mensaje_out = 'Trabajador trasladado correctamente a la empresa destino.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('%s', 16, 1, @err);
        RETURN;
    END CATCH;

    SELECT
        @cia_origen AS cia_origen,
        @cia_destino AS cia_destino,
        @person AS person,
        @mensaje_out AS mensaje;
END
GO
