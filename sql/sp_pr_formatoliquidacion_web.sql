/*
    Formato de Liquidación — cabecera del documento (dw PowerBuilder liquidación).

    Filtro de planilla: PROCESSTYPE = LIQUIDACION (liquidación del periodo).

    Parámetros:
      @cia         — compañía
      @payrolltype — tipo de planilla
      @period      — periodo PRPeriod
      @person      — código trabajador
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_formatoliquidacion_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sc.Description AS company_name,
        sc.Address AS company_address,
        sc.Telephone AS company_telephone,
        sc.Ruc AS company_ruc,
        ISNULL(sc.Representative, '') AS nombre_representante,
        ISNULL(sc.Rep_Position, '') AS cargo_representante,
        pe.Person AS person,
        sp.DocumentNumber AS person_document,
        ISNULL(dt.Description, 'DNI') AS document_type,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' + ISNULL(sp.LastName2, '') + ' '
            + ISNULL(sp.Name1, '') + ' ' + ISNULL(sp.Name2, '')
        )) AS person_name,
        ISNULL(pp.Description, '') AS person_position,
        ISNULL(cm.Description, '') AS contract_modality,
        ISNULL((
            SELECT SUM(EC.ConceptValue)
            FROM PR_EmployeePayRollConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK) ON EC.Concept = C.Concept
            WHERE EC.Company = @cia
              AND EC.Person = pe.Person
              AND EC.PayRollType = @payrolltype
              AND EC.PRPeriod = @period
              AND EC.ProcessType = epc.ProcessType
              AND C.FormulaCode = 'LIQ_REM_BASICA'
        ), 0) AS basico,
        epc.EntryDate AS entry_date,
        epc.CeaseDate AS cease_date,
        ISNULL(cr.Description, ISNULL(epc.CeaseReason, '')) AS cease_reason,
        CASE
            WHEN pt_pens.PDT IN ('21', '22', '23', '24', '25') THEN ISNULL(afp.Description, '')
            WHEN pt_pens.PDT = '02' THEN 'ONP'
            ELSE ''
        END AS type_pension,
        CASE
            WHEN pt_pens.PDT IN ('21', '22', '23', '24', '25') THEN ISNULL(afp.PensionPercentage, 0)
            ELSE 0
        END AS porc_aporte,
        CASE
            WHEN pt_pens.PDT IN ('21', '22', '23', '24', '25') THEN ISNULL(afp.FixedAmount, 0)
            ELSE 0
        END AS porc_comision,
        CASE
            WHEN pt_pens.PDT IN ('21', '22', '23', '24', '25') THEN ISNULL(afp.InsuredPercentage, 0)
            ELSE 0
        END AS porc_seguro,
        ISNULL((
            SELECT ParameterNumberValue
            FROM PR_Parameter (NOLOCK)
            WHERE Company = @cia
              AND ShortName = 'PORC_ONP'
        ), 0) AS porc_onp,
        ISNULL((
            SELECT ParameterNumberValue
            FROM PR_Parameter (NOLOCK)
            WHERE Company = @cia
              AND ShortName = 'PORC_EPS'
        ), 0) AS porc_eps,
        ISNULL((
            SELECT TOP 1 ParameterNumberValue
            FROM PR_Parameter (NOLOCK)
            WHERE Company = @cia
              AND ShortName LIKE '%PORC_SEG_SOCIAL%'
        ), 0) AS porc_seg_social,
        CASE
            WHEN pt_pens.PDT <> '02' THEN
                CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM PR_EmployeeConcept ec (NOLOCK)
                            INNER JOIN PR_Concept c (NOLOCK) ON c.Concept = ec.Concept
                        WHERE ec.Person = pe.Person
                          AND ec.PayRollType = @payrolltype
                          AND c.FormulaCode = 'AFP_FLUJO'
                    ) THEN 'MIXTO'
                    ELSE 'FLUJO'
                END
            ELSE ''
        END AS tipo_comision,
        ISNULL(pe.SalaryAccount, '') AS salary_account,
        ISNULL(bank.Name, '') AS salary_bank,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept ec (NOLOCK)
                    INNER JOIN PR_Concept c (NOLOCK) ON c.Concept = ec.Concept
                WHERE ec.Person = pe.Person
                  AND ec.PayRollType = @payrolltype
                  AND c.FormulaCode = 'FLAG_MYPE'
            ) THEN 'MYPE'
            ELSE 'GENERAL'
        END AS regimen_laboral,
        ISNULL((
            SELECT SUM(ISNULL(EC.ConceptValue, EC.ConceptValueLo))
            FROM PR_EmployeePayRollConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK) ON EC.Concept = C.Concept
            WHERE EC.Company = @cia
              AND EC.Person = pe.Person
              AND EC.PayRollType = @payrolltype
              AND EC.PRPeriod = @period
              AND EC.ProcessType = epc.ProcessType
              AND C.FormulaCode = 'ANIO'
        ), 0) AS anios_servicio,
        ISNULL((
            SELECT SUM(ISNULL(EC.ConceptValue, EC.ConceptValueLo))
            FROM PR_EmployeePayRollConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK) ON EC.Concept = C.Concept
            WHERE EC.Company = @cia
              AND EC.Person = pe.Person
              AND EC.PayRollType = @payrolltype
              AND EC.PRPeriod = @period
              AND EC.ProcessType = epc.ProcessType
              AND C.FormulaCode = 'MES'
        ), 0) AS meses_servicio,
        ISNULL((
            SELECT SUM(ISNULL(EC.ConceptValue, EC.ConceptValueLo))
            FROM PR_EmployeePayRollConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK) ON EC.Concept = C.Concept
            WHERE EC.Company = @cia
              AND EC.Person = pe.Person
              AND EC.PayRollType = @payrolltype
              AND EC.PRPeriod = @period
              AND EC.ProcessType = epc.ProcessType
              AND C.FormulaCode = 'DIA'
        ), 0) AS dias_servicio
    FROM PR_Employee pe (NOLOCK)
        INNER JOIN SY_Person sp (NOLOCK) ON pe.Person = sp.Person
        INNER JOIN SY_Company sc (NOLOCK) ON pe.Company = sc.Company
        LEFT JOIN PR_Position pp (NOLOCK) ON pe.Position = pp.Position
        LEFT JOIN HR_ContractModality cm (NOLOCK) ON pe.ContractModality = cm.ContractModality
        LEFT JOIN SY_PersonDocumentType dt (NOLOCK) ON sp.EmployeeDocumentType = dt.PersonDocumentType
        LEFT JOIN PR_PensionType pt_pens (NOLOCK) ON pe.PensionType = pt_pens.PensionType
        LEFT JOIN PR_AFP afp (NOLOCK)
            ON pe.AFP = afp.AFP
           AND afp.Company = @cia
        LEFT JOIN ERP_Bank bank (NOLOCK) ON pe.SalaryBank = bank.Bank
        INNER JOIN PR_EmployeePayRoll epc (NOLOCK) ON pe.Person = epc.Person
        LEFT JOIN PR_CeaseReason cr (NOLOCK)
            ON cr.Company = @cia
           AND cr.CeaseReason = epc.CeaseReason
        INNER JOIN PR_ProcessType pt_liq (NOLOCK)
            ON epc.ProcessType = pt_liq.ProcessType
           AND epc.Company = pt_liq.Company
    WHERE pe.Company = @cia
      AND epc.Company = @cia
      AND epc.PayRollType = @payrolltype
      AND epc.PRPeriod = @period
      AND epc.Person = @person
      AND pt_liq.ShortName = 'LIQUIDACION'
      AND EXISTS (
            SELECT 1
            FROM PR_EmployeePayRollConcept epc2 (NOLOCK)
            WHERE epc2.Company = @cia
              AND epc2.Person = @person
              AND epc2.ProcessType = epc.ProcessType
              AND epc2.PayRollType = @payrolltype
              AND epc2.PRPeriod = @period
        );
END
GO
