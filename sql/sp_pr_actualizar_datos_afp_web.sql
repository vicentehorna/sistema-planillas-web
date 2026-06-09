/*
    Control de datos AFP — actualiza PR_EmployeeAFP y PR_EmployeeAFPHeader.

    Usado por: POST /api/declaracion-afp/generar-xlsx (antes de generar el Excel AFPnet).

    Basado en: AUXILIARES/control de datos AFP.txt (PowerBuilder w_pr_afp_calc_list).

    Solo procesa combinaciones planilla/proceso que tengan concepto formulacode = TOTAL_REM_AFP
    en PR_EmployeePayRollConcept para el periodo indicado.

    Parámetros:
      @cia         — compañía
      @period      — periodo YYYYMM (6 dígitos)
      @payroll_all — Y = todas las planillas con TOTAL_REM_AFP, N = filtrar por @payroll
      @payroll     — tipo de planilla
      @xlastuser   — usuario que ejecuta el proceso
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_datos_afp_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @xlastuser   VARCHAR(20) = 'WEB'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @xlastuser = LTRIM(RTRIM(ISNULL(@xlastuser, 'WEB')));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @payroll_all = 'Y' SET @payroll = '';

    DECLARE
        @AFPAssureableRemConcept VARCHAR(20),
        @AFPFixedAmountConcept VARCHAR(20),
        @AFPVariableAmountConcept VARCHAR(20),
        @AFPInsuredAmountConcept VARCHAR(20),
        @AFPARComisionAmountConcept VARCHAR(20),
        @AFPEmployerContribution VARCHAR(20),
        @LiquidacionProcess VARCHAR(20),
        @DefaultReplicationUnit VARCHAR(4);

    SELECT
        @AFPAssureableRemConcept = LTRIM(RTRIM(AFPAssureableRemConcept)),
        @AFPFixedAmountConcept = LTRIM(RTRIM(AFPFixedAmountConcept)),
        @AFPVariableAmountConcept = LTRIM(RTRIM(AFPVariableAmountConcept)),
        @AFPInsuredAmountConcept = LTRIM(RTRIM(AFPInsuredAmountConcept)),
        @AFPARComisionAmountConcept = LTRIM(RTRIM(AFPARComisionAmountConcept)),
        @AFPEmployerContribution = LTRIM(RTRIM(AfpEmployerContribution)),
        @LiquidacionProcess = LTRIM(RTRIM(LiquidacionProcess))
    FROM pr_mapping (NOLOCK)
    WHERE Company = @cia;

    IF @AFPAssureableRemConcept IS NULL OR @AFPFixedAmountConcept IS NULL
       OR @AFPVariableAmountConcept IS NULL OR @AFPInsuredAmountConcept IS NULL
       OR @AFPARComisionAmountConcept IS NULL
    BEGIN
        RAISERROR('Debe configurarse los conceptos AFP de la compañía en PR_Mapping.', 16, 1);
        RETURN;
    END

    SELECT TOP 1 @DefaultReplicationUnit = LTRIM(RTRIM(ReplicationUnit))
    FROM sy_replicationunit (NOLOCK)
    ORDER BY ReplicationUnit;

    CREATE TABLE #PlanillasProcesar (
        payrolltype VARCHAR(20) NOT NULL,
        processtype VARCHAR(20) NOT NULL,
        PRIMARY KEY (payrolltype, processtype)
    );

    INSERT INTO #PlanillasProcesar (payrolltype, processtype)
    SELECT DISTINCT
        LTRIM(RTRIM(EPC.PayRollType)),
        LTRIM(RTRIM(EPC.ProcessType))
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON EPC.Concept = C.Concept
           AND EPC.Company = C.Company
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND C.FormulaCode = 'TOTAL_REM_AFP'
      AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll);

    IF NOT EXISTS (SELECT 1 FROM #PlanillasProcesar)
    BEGIN
        SELECT
            0 AS actualizado,
            0 AS filas_afp,
            0 AS filas_header,
            'No hay combinaciones planilla/proceso con concepto TOTAL_REM_AFP para el periodo.' AS mensaje;
        RETURN;
    END

    CREATE TABLE #ConceptosAfp (
        person VARCHAR(20) NOT NULL,
        company VARCHAR(4) NOT NULL,
        payrolltype VARCHAR(20) NOT NULL,
        processtype VARCHAR(20) NOT NULL,
        prperiod VARCHAR(20) NOT NULL,
        concept VARCHAR(20) NOT NULL,
        conceptcurrency CHAR(2) NULL,
        exchangerate NUMERIC(18, 4) NULL,
        conceptvalue NUMERIC(18, 4) NOT NULL,
        conceptvaluelo NUMERIC(18, 4) NOT NULL,
        conceptvalueex NUMERIC(18, 4) NOT NULL,
        afpcard VARCHAR(20) NULL,
        ceasedate DATETIME NULL,
        entrydate DATETIME NULL,
        afp VARCHAR(20) NULL,
        costcenter VARCHAR(20) NULL,
        costcentername VARCHAR(20) NULL,
        replicationunit VARCHAR(4) NULL
    );

    INSERT INTO #ConceptosAfp (
        person, company, payrolltype, processtype, prperiod, concept,
        conceptcurrency, exchangerate, conceptvalue, conceptvaluelo, conceptvalueex,
        afpcard, ceasedate, entrydate, afp, costcenter, costcentername, replicationunit
    )
    SELECT
        LTRIM(RTRIM(EPC.Person)),
        LTRIM(RTRIM(EPC.Company)),
        LTRIM(RTRIM(EPC.PayRollType)),
        LTRIM(RTRIM(EPC.ProcessType)),
        LTRIM(RTRIM(EPC.PRPeriod)),
        LTRIM(RTRIM(EPC.Concept)),
        EPC.ConceptCurrency,
        EPC.ExchangeRate,
        ISNULL(EPC.ConceptValue, 0),
        ISNULL(EPC.ConceptValueLo, 0),
        ISNULL(EPC.ConceptValueEx, 0),
        LTRIM(RTRIM(EP.AFPCard)),
        EP.CeaseDate,
        EP.EntryDate,
        LTRIM(RTRIM(EP.AFP)),
        LTRIM(RTRIM(EP.CostCenter)),
        LTRIM(RTRIM(EP.CostCenterName)),
        LTRIM(RTRIM(ISNULL(EP.ReplicationUnit, EPC.ReplicationUnit)))
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
            ON EPC.Company = EP.Company
           AND EPC.PayRollType = EP.PayRollType
           AND EPC.PRPeriod = EP.PRPeriod
           AND EPC.Person = EP.Person
           AND EPC.ProcessType = EP.ProcessType
        INNER JOIN #PlanillasProcesar PP
            ON EPC.PayRollType = PP.payrolltype
           AND EPC.ProcessType = PP.processtype
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND (
            EPC.Concept = @AFPAssureableRemConcept
         OR EPC.Concept = @AFPFixedAmountConcept
         OR EPC.Concept = @AFPVariableAmountConcept
         OR EPC.Concept = @AFPInsuredAmountConcept
         OR EPC.Concept = @AFPARComisionAmountConcept
         OR EPC.Concept = @AFPEmployerContribution
      );

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE H
        FROM PR_EmployeeAFPHeader H
            INNER JOIN (
                SELECT DISTINCT payrolltype FROM #PlanillasProcesar
            ) P ON H.PayRollType = P.payrolltype
        WHERE H.Company = @cia
          AND LEFT(H.PRPeriod, 6) = @period;

        DELETE A
        FROM PR_EmployeeAFP A
            INNER JOIN (
                SELECT DISTINCT payrolltype FROM #PlanillasProcesar
            ) P ON A.PayRollType = P.payrolltype
        WHERE A.Company = @cia
          AND LEFT(A.PRPeriod, 6) = @period;

        INSERT INTO PR_EmployeeAFP (
            Person, Company, PRPeriod, AFP, AFPCurrency, AFPExchangeRate,
            AssureableRemAmount, AssureableRemAmountLo, AssureableRemAmountEx,
            FixedAmount, FixedAmountLo, FixedAmountEx,
            VariableAmount, VariableAmountLo, VariableAmountEx,
            InsuredAmount, InsuredAmountLo, InsuredAmountEx,
            ARComisionAmount, ARComisionAmountLo, ARComisionAmountEx,
            EmployerContribution, EmployerContributionLo, EmployerContributionEx,
            ReplicationUnit, XLastUser, XLastDate,
            Costcenter, Costcentername, payrolltype, ceasedate, afpcard, entrydate
        )
        SELECT
            S.person,
            S.company,
            S.prperiod,
            S.afp,
            S.conceptcurrency,
            S.exchangerate,
            S.AssureableRemAmount,
            S.AssureableRemAmountLo,
            S.AssureableRemAmountEx,
            S.FixedAmount,
            S.FixedAmountLo,
            S.FixedAmountEx,
            S.VariableAmount,
            S.VariableAmountLo,
            S.VariableAmountEx,
            S.InsuredAmount,
            S.InsuredAmountLo,
            S.InsuredAmountEx,
            S.ARComisionAmount,
            S.ARComisionAmountLo,
            S.ARComisionAmountEx,
            S.EmployerContribution,
            S.EmployerContributionLo,
            S.EmployerContributionEx,
            CASE
                WHEN ISNULL(S.replicationunit, '') = '' THEN @DefaultReplicationUnit
                ELSE S.replicationunit
            END,
            @xlastuser,
            GETDATE(),
            S.costcenter,
            S.costcentername,
            S.payrolltype,
            EM.ceasedate,
            S.afpcard,
            ISNULL(EM.reentrydate, EM.entrydate) AS entrydate
        FROM (
            SELECT
                C.person,
                C.company,
                LEFT(C.prperiod, 6) + SUBSTRING(C.prperiod, 5, 2) AS prperiod,
                MAX(C.afp) AS afp,
                MAX(C.conceptcurrency) AS conceptcurrency,
                MAX(C.exchangerate) AS exchangerate,
                SUM(CASE WHEN C.concept = @AFPAssureableRemConcept THEN C.conceptvalue ELSE 0 END) AS AssureableRemAmount,
                SUM(CASE WHEN C.concept = @AFPAssureableRemConcept THEN C.conceptvaluelo ELSE 0 END) AS AssureableRemAmountLo,
                SUM(CASE WHEN C.concept = @AFPAssureableRemConcept THEN C.conceptvalueex ELSE 0 END) AS AssureableRemAmountEx,
                SUM(CASE WHEN C.concept = @AFPFixedAmountConcept THEN C.conceptvalue ELSE 0 END) AS FixedAmount,
                SUM(CASE WHEN C.concept = @AFPFixedAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS FixedAmountLo,
                SUM(CASE WHEN C.concept = @AFPFixedAmountConcept THEN C.conceptvalueex ELSE 0 END) AS FixedAmountEx,
                SUM(CASE WHEN C.concept = @AFPVariableAmountConcept THEN C.conceptvalue ELSE 0 END) AS VariableAmount,
                SUM(CASE WHEN C.concept = @AFPVariableAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS VariableAmountLo,
                SUM(CASE WHEN C.concept = @AFPVariableAmountConcept THEN C.conceptvalueex ELSE 0 END) AS VariableAmountEx,
                SUM(CASE WHEN C.concept = @AFPInsuredAmountConcept THEN C.conceptvalue ELSE 0 END) AS InsuredAmount,
                SUM(CASE WHEN C.concept = @AFPInsuredAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS InsuredAmountLo,
                SUM(CASE WHEN C.concept = @AFPInsuredAmountConcept THEN C.conceptvalueex ELSE 0 END) AS InsuredAmountEx,
                SUM(CASE WHEN C.concept = @AFPARComisionAmountConcept THEN C.conceptvalue ELSE 0 END) AS ARComisionAmount,
                SUM(CASE WHEN C.concept = @AFPARComisionAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS ARComisionAmountLo,
                SUM(CASE WHEN C.concept = @AFPARComisionAmountConcept THEN C.conceptvalueex ELSE 0 END) AS ARComisionAmountEx,
                SUM(CASE WHEN C.concept = @AFPEmployerContribution THEN C.conceptvalue ELSE 0 END) AS EmployerContribution,
                SUM(CASE WHEN C.concept = @AFPEmployerContribution THEN C.conceptvaluelo ELSE 0 END) AS EmployerContributionLo,
                SUM(CASE WHEN C.concept = @AFPEmployerContribution THEN C.conceptvalueex ELSE 0 END) AS EmployerContributionEx,
                MAX(C.replicationunit) AS replicationunit,
                MAX(C.costcenter) AS costcenter,
                MAX(C.costcentername) AS costcentername,
                MAX(C.payrolltype) AS payrolltype,
                MAX(C.afpcard) AS afpcard,
                SUM(CASE
                    WHEN C.concept IN (
                        @AFPFixedAmountConcept, @AFPVariableAmountConcept,
                        @AFPInsuredAmountConcept, @AFPARComisionAmountConcept, @AFPEmployerContribution
                    ) THEN 1 ELSE 0
                END) AS tiene_aportes
            FROM #ConceptosAfp C
            GROUP BY C.person, C.company, C.payrolltype, LEFT(C.prperiod, 6) + SUBSTRING(C.prperiod, 5, 2)
        ) S
            INNER JOIN pr_employee EM (NOLOCK)
                ON EM.person = S.person
               AND EM.company = S.company
        WHERE S.tiene_aportes > 0;

        INSERT INTO PR_EmployeeAFPHeader (
            Company, ReplicationUnit, PRPeriod, PayRollType, AFP, costcenter,
            costcentername, PaymentStatus, XLastUser, XLastDate
        )
        SELECT
            A.Company,
            A.ReplicationUnit,
            A.PRPeriod,
            A.PayRollType,
            A.AFP,
            A.Costcenter,
            MAX(A.Costcentername),
            'P',
            @xlastuser,
            GETDATE()
        FROM PR_EmployeeAFP A (NOLOCK)
        WHERE A.Company = @cia
          AND LEFT(A.PRPeriod, 6) = @period
          AND A.PayRollType IN (SELECT DISTINCT payrolltype FROM #PlanillasProcesar)
          AND ISNULL(A.ReplicationUnit, '') <> ''
        GROUP BY
            A.Company, A.ReplicationUnit, A.PRPeriod, A.PayRollType, A.AFP, A.Costcenter;

        UPDATE PR_EmployeeAFP
        SET AssureableRemAmountLo = AssureableRemAmount
        WHERE Company = @cia
          AND LEFT(PRPeriod, 4) = LEFT(@period, 4);

        COMMIT TRANSACTION;

        SELECT
            1 AS actualizado,
            (SELECT COUNT(*) FROM PR_EmployeeAFP (NOLOCK)
             WHERE Company = @cia AND LEFT(PRPeriod, 6) = @period
               AND PayRollType IN (SELECT DISTINCT payrolltype FROM #PlanillasProcesar)) AS filas_afp,
            (SELECT COUNT(*) FROM PR_EmployeeAFPHeader (NOLOCK)
             WHERE Company = @cia AND LEFT(PRPeriod, 6) = @period
               AND PayRollType IN (SELECT DISTINCT payrolltype FROM #PlanillasProcesar)) AS filas_header,
            'Control de datos AFP ejecutado correctamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err VARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en control de datos AFP: %s', 16, 1, @err);
    END CATCH
END
GO
