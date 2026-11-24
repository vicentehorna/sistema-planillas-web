/*
  SP_PR_DELETECOMPANY — versión ampliada (hm_garc / web)

  Cambios vs PowerBuilder original:
  1) Elimina UPDATE globales a PR_ImportConceptDetail / ERP_DocumentSerie
     (afectaban TODAS las empresas).
  2) Borra tablas operativas/transaccionales que quedaban huérfanas:
     PR_Employee, PR_EmployeePayRollConcept(+Detail), fórmulas,
     vacaciones, AFP empleado, logs, etc.
  3) Incluye hijos FK de SY_Company no cubiertos antes.
  4) Valida @company y usa transacción.

  Uso:
    EXEC SP_PR_DELETECOMPANY @company = 'S283';
*/
CREATE OR ALTER PROCEDURE [dbo].[SP_PR_DELETECOMPANY]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @cia VARCHAR(4) = LTRIM(RTRIM(ISNULL(@company, '')));
    DECLARE @ruc VARCHAR(20);

    IF @cia = '' OR LEN(@cia) > 4
    BEGIN
        RAISERROR('Company inválida.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM SY_Company WHERE Company = @cia)
    BEGIN
        RAISERROR('La empresa no existe en SY_Company.', 16, 1);
        RETURN;
    END;

    /* No permitir borrar la CIA base BGT por accidente */
    IF @cia = 'BGT'
    BEGIN
        RAISERROR('No se permite eliminar la empresa base BGT con este SP.', 16, 1);
        RETURN;
    END;

    SELECT @ruc = LTRIM(RTRIM(ISNULL(RUC, ''))) FROM SY_Company WHERE Company = @cia;

    BEGIN TRY
        BEGIN TRAN;

        /* ===== Desactivar FKs (maestros / tablas tocadas) ===== */
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_AFP';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ProcessType';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_AccountProfile';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_PayRollType';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Ocupation';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Parameter';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Concept';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ConceptSet';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ConceptSetDetail';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Report';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ReportSort';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ReportGroup';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ReportDetail';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ImportConcept';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ImportConceptDetail';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_LiquidationSection';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'SY_STREETTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'SY_ZONE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_LOCALTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_EMPLOYEESTATUS';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'SY_PERSONDOCUMENTTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_PERIODTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_CEASEREASON';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'SY_FAMILIYLINK';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_MEDICALRESTTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ACTIVITYTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_NACIONALIDAD';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_INSTRUCTIONLEVEL';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'HR_CONTRACTMODALITY';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_HEALTHENTITY';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_MODALITYFORMATIVE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_DEPENNACTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_RegimenLabour';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_EmployeeCategory';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_SCTR';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_SPECIALSTATUS';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_FATHERHOODDOC';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_EMPLOYEETYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_PENSIONTYPE';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_DriverLicenseType';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_LoanReason';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ProfessionalTraining';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_TYPEPROOF';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_LOCALCONDITION';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_SocialAssistanceCardType';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ProfessionalCategory';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_TaxAgreement';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_OccupationalGroup';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Mode';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_GenPensionType';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_IncomeType';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_AccountType';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_ConceptAffect';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_WindowProcessGeneral';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_WindowProcess';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_WindowProcess_Order';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_WindowProcess_Value';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Formula';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Function';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_GroupSubroutine';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_Subroutine';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'te_accounttype';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'erp_bank';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'AC_Account';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'te_bankaccount';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'SY_ApplicationPeriod';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_PERIOD';
        EXEC Usp_Activa_Desactiva_Llaves 'NO', 'PR_FunctionParameter';

        /* ===== 1) Transacciones / cálculo / empleado ===== */
        IF OBJECT_ID('dbo.PR_EmployeePayRollConceptDetail', 'U') IS NOT NULL
            DELETE FROM PR_EmployeePayRollConceptDetail WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_EmployeePayRollConcept', 'U') IS NOT NULL
            DELETE FROM PR_EmployeePayRollConcept WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_PayrollLog', 'U') IS NOT NULL
            DELETE FROM PR_PayrollLog WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_EmployeeAFP', 'U') IS NOT NULL
            DELETE FROM PR_EmployeeAFP WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_EmployeeAFPHeader', 'U') IS NOT NULL
            DELETE FROM PR_EmployeeAFPHeader WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_HistoricoFechas', 'U') IS NOT NULL
            DELETE FROM PR_HistoricoFechas WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_HistoricoPension', 'U') IS NOT NULL
            DELETE FROM PR_HistoricoPension WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_VacationDetail', 'U') IS NOT NULL
            DELETE FROM PR_VacationDetail WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_VacationPay', 'U') IS NOT NULL
            DELETE FROM PR_VacationPay WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_Vacation', 'U') IS NOT NULL
            DELETE FROM PR_Vacation WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_EmployeeMedicalRest', 'U') IS NOT NULL
            DELETE FROM PR_EmployeeMedicalRest WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_DocumentPerson', 'U') IS NOT NULL
            DELETE FROM PR_DocumentPerson WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_RegisterHour', 'U') IS NOT NULL
            DELETE FROM PR_RegisterHour WHERE Company = @cia;

        IF OBJECT_ID('dbo.CA_Photocheck', 'U') IS NOT NULL
            DELETE FROM CA_Photocheck WHERE Company = @cia;

        IF OBJECT_ID('dbo.PeriodsIndicators', 'U') IS NOT NULL
            DELETE FROM PeriodsIndicators WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_CompanyPlame', 'U') IS NOT NULL
            DELETE FROM PR_CompanyPlame WHERE Company = @cia;

        DELETE FROM PR_EmployeeLocal WHERE Company = @cia;
        DELETE FROM PR_TaxRentEmployee WHERE Company = @cia;
        DELETE FROM PR_TaxRentDetail WHERE Company = @cia;
        DELETE FROM PR_EmployeeConcept WHERE Company = @cia;
        DELETE FROM PR_EmployeeCTSConcept WHERE Company = @cia;
        DELETE FROM PR_EMPLOYEEPAYROLL WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_Position', 'U') IS NOT NULL
            DELETE FROM PR_Position WHERE Company = @cia;

        /* Fórmulas (detalle antes que cabecera) */
        IF OBJECT_ID('dbo.PR_FormulaDetail', 'U') IS NOT NULL
            DELETE FROM PR_FormulaDetail WHERE Company = @cia
               OR FormulaHeader IN (SELECT FormulaHeader FROM PR_FormulaHeader WHERE Company = @cia);

        IF OBJECT_ID('dbo.PR_FormulaHeader', 'U') IS NOT NULL
            DELETE FROM PR_FormulaHeader WHERE Company = @cia;

        DELETE FROM PR_Formula WHERE Company = @cia;

        /* Empleados de la CIA (después de dependencias) */
        IF OBJECT_ID('dbo.PR_Employee', 'U') IS NOT NULL
            DELETE FROM PR_Employee WHERE Company = @cia;

        IF OBJECT_ID('dbo.SY_UserCompany', 'U') IS NOT NULL
            DELETE FROM SY_UserCompany WHERE Company = @cia;

        /* ===== 2) Maestros / config (orden original ampliado) ===== */
        DELETE FROM PR_AFP WHERE Company = @cia;
        DELETE FROM PR_ProcessControl WHERE Company = @cia;
        DELETE FROM PR_PayRollTypeProcess WHERE Company = @cia;
        DELETE FROM PR_ProcessType WHERE Company = @cia;
        DELETE FROM PR_AccountProfile WHERE Company = @cia;
        DELETE FROM PR_PayRollType WHERE Company = @cia;
        DELETE FROM PR_Ocupation WHERE Company = @cia;
        DELETE FROM PR_Parameter WHERE Company = @cia;
        DELETE FROM PR_ReportDetail WHERE Company = @cia;
        DELETE FROM PR_ConceptSetDetail WHERE Company = @cia;
        DELETE FROM PR_Subroutine WHERE Company = @cia;
        DELETE FROM PR_GroupSubroutine WHERE Company = @cia;

        DELETE FROM PR_Concept WHERE Company = @cia;
        DELETE FROM PR_ConceptGroup WHERE Company = @cia;
        DELETE FROM PR_ConceptSet WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_ConceptType', 'U') IS NOT NULL
            DELETE FROM PR_ConceptType WHERE Company = @cia;

        DELETE FROM PR_ReportSort WHERE Company = @cia;
        DELETE FROM PR_ReportGroup WHERE Company = @cia;
        DELETE FROM PR_ReportDetail WHERE Company = @cia;
        DELETE FROM PR_Report WHERE Company = @cia;
        DELETE FROM PR_ImportConceptDetail WHERE Company = @cia;
        DELETE FROM PR_ImportConcept WHERE Company = @cia;
        DELETE FROM PR_LiquidationSection WHERE Company = @cia;

        DELETE FROM SY_STREETTYPE WHERE Company = @cia;
        DELETE FROM SY_ZONE WHERE Company = @cia;
        DELETE FROM PR_LOCALTYPE WHERE Company = @cia;
        DELETE FROM PR_EMPLOYEESTATUS WHERE Company = @cia;
        DELETE FROM SY_PERSONDOCUMENTTYPE WHERE Company = @cia;
        DELETE FROM PR_PERIODTYPE WHERE Company = @cia;
        DELETE FROM PR_CEASEREASON WHERE Company = @cia;
        DELETE FROM SY_FAMILIYLINK WHERE Company = @cia;
        DELETE FROM PR_MEDICALRESTTYPE WHERE Company = @cia;
        DELETE FROM PR_ACTIVITYTYPE WHERE Company = @cia;
        DELETE FROM PR_NACIONALIDAD WHERE Company = @cia;
        DELETE FROM PR_INSTRUCTIONLEVEL WHERE Company = @cia;
        DELETE FROM HR_CONTRACTMODALITY WHERE Company = @cia;
        DELETE FROM PR_HEALTHENTITY WHERE Company = @cia;

        /* PR_MODALITYFORMATIVE es catálogo global (sin Company): no borrar */

        DELETE FROM PR_DEPENNACTYPE WHERE Company = @cia;
        DELETE FROM PR_RegimenLabour WHERE Company = @cia;
        DELETE FROM PR_EmployeeCategory WHERE Company = @cia;
        DELETE FROM PR_SCTR WHERE Company = @cia;
        DELETE FROM PR_SPECIALSTATUS WHERE Company = @cia;
        DELETE FROM PR_FATHERHOODDOC WHERE Company = @cia;
        DELETE FROM PR_EMPLOYEETYPE WHERE Company = @cia;
        DELETE FROM PR_PENSIONTYPE WHERE Company = @cia;
        DELETE FROM PR_DriverLicenseType WHERE Company = @cia;
        DELETE FROM PR_LoanReason WHERE Company = @cia;
        DELETE FROM PR_ProfessionalTraining WHERE Company = @cia;

        /* PR_TYPEPROOF es catálogo global (sin Company): no borrar */

        IF OBJECT_ID('dbo.PR_REGIMEHEALTH', 'U') IS NOT NULL
            DELETE FROM PR_REGIMEHEALTH WHERE Company = @cia;

        DELETE FROM PR_LOCALCONDITION WHERE Company = @cia;
        DELETE FROM PR_SocialAssistanceCardType WHERE Company = @cia;
        DELETE FROM PR_ProfessionalCategory WHERE Company = @cia;
        DELETE FROM PR_TaxAgreement WHERE Company = @cia;
        DELETE FROM PR_OccupationalGroup WHERE Company = @cia;
        DELETE FROM PR_Mode WHERE Company = @cia;
        DELETE FROM PR_GenPensionType WHERE Company = @cia;
        DELETE FROM PR_IncomeType WHERE Company = @cia;
        DELETE FROM PR_AccountType WHERE Company = @cia;
        DELETE FROM PR_ConceptAffect WHERE Company = @cia;

        /* PR_WindowProcessGeneral es catálogo global (sin Company): no borrar */

        DELETE FROM PR_WindowProcess WHERE Company = @cia;
        DELETE FROM PR_WindowProcess_Order WHERE Company = @cia;
        DELETE FROM PR_WindowProcess_Value WHERE Company = @cia;

        DELETE FROM PR_FunctionPARAMETER WHERE Company = @cia;
        DELETE FROM PR_Function WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_FunctionGroup', 'U') IS NOT NULL
            DELETE FROM PR_FunctionGroup WHERE Company = @cia;

        IF OBJECT_ID('dbo.PR_FunctionType', 'U') IS NOT NULL
            DELETE FROM PR_FunctionType WHERE Company = @cia;

        DELETE FROM te_accounttype WHERE Company = @cia;
        DELETE FROM erp_bank WHERE Company = @cia;
        DELETE FROM AC_Account WHERE Company = @cia;
        DELETE FROM te_bankaccount WHERE Company = @cia;

        IF OBJECT_ID('dbo.AC_CostCenter', 'U') IS NOT NULL
            DELETE FROM AC_CostCenter WHERE Company = @cia;

        DELETE FROM PR_Mapping WHERE Company = @cia;
        DELETE FROM AC_Mapping WHERE Company = @cia;
        DELETE FROM CA_Mapping WHERE Company = @cia;
        DELETE FROM TE_Mapping WHERE Company = @cia;
        DELETE FROM AP_Mapping WHERE Company = @cia;
        DELETE FROM AR_Mapping WHERE Company = @cia;
        DELETE FROM BG_Mapping WHERE Company = @cia;
        DELETE FROM CC_Mapping WHERE Company = @cia;
        DELETE FROM FA_MAPPING WHERE Company = @cia;
        DELETE FROM MA_MAPPING WHERE Company = @cia;
        DELETE FROM PO_Mapping WHERE Company = @cia;
        DELETE FROM PP_Mapping WHERE Company = @cia;

        IF OBJECT_ID('dbo.WH_Mapping', 'U') IS NOT NULL
            DELETE FROM WH_Mapping WHERE Company = @cia;

        IF OBJECT_ID('dbo.WH_WareHouse', 'U') IS NOT NULL
            DELETE FROM WH_WareHouse WHERE Company = @cia;

        DELETE FROM SY_ApplicationPeriod WHERE Company = @cia;
        DELETE FROM SY_ApplicationCompany WHERE Company = @cia;
        DELETE FROM SY_BusinessUnit WHERE Company = @cia;

        /* WH_TransactionType: por Company y por DocumentType de la CIA */
        DELETE FROM WH_TransactionType
        WHERE Company = @cia
           OR DocumentType IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia);

        IF OBJECT_ID('dbo.WH_Transaction', 'U') IS NOT NULL
            DELETE FROM WH_Transaction
            WHERE Company = @cia
               OR DocumentType IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia);

        /* MappingPC puede referenciar series/tipos de la CIA */
        IF OBJECT_ID('dbo.ERP_MappingPC', 'U') IS NOT NULL
            DELETE FROM ERP_MappingPC
            WHERE Company = @cia
               OR DocTypeAjust IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia)
               OR DocTypeTransfer IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia)
               OR DocTypeInput IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia)
               OR DocTypeOutput IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia)
               OR SaleDocType IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia);

        DELETE FROM AP_DocumentType WHERE Company = @cia;

        /* DocumentType: hijos antes que ERP_DocumentType */
        IF OBJECT_ID('dbo.ERP_DocumentType_Form', 'U') IS NOT NULL
            DELETE FROM ERP_DocumentType_Form
            WHERE DocumentType IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia);

        IF OBJECT_ID('dbo.ERP_DocumentTypeTax', 'U') IS NOT NULL
            DELETE FROM ERP_DocumentTypeTax
            WHERE DocumentType IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia);

        /* Series: Company puede ser NULL aunque DocumentType sea de la CIA */
        DELETE FROM ERP_DocumentSerie
        WHERE Company = @cia
           OR DocumentType IN (SELECT DocumentType FROM ERP_DocumentType WHERE Company = @cia);

        DELETE FROM erp_documenttype WHERE Company = @cia;

        /* Tax / ServiceType: hijos antes que ERP_Tax */
        IF OBJECT_ID('dbo.AP_DocumentTax', 'U') IS NOT NULL
            DELETE FROM AP_DocumentTax
            WHERE Tax IN (SELECT Tax FROM ERP_Tax WHERE Company = @cia);

        IF OBJECT_ID('dbo.AR_DocumentTax', 'U') IS NOT NULL
            DELETE FROM AR_DocumentTax
            WHERE Tax IN (SELECT Tax FROM ERP_Tax WHERE Company = @cia);

        IF OBJECT_ID('dbo.PO_PurchaseOrderTax', 'U') IS NOT NULL
            DELETE FROM PO_PurchaseOrderTax
            WHERE Tax IN (SELECT Tax FROM ERP_Tax WHERE Company = @cia);

        IF OBJECT_ID('dbo.AP_ServiceTypeTax', 'U') IS NOT NULL
            DELETE FROM AP_ServiceTypeTax WHERE Company = @cia;

        IF OBJECT_ID('dbo.AP_ServiceType', 'U') IS NOT NULL
            DELETE FROM AP_ServiceType WHERE Company = @cia;

        IF OBJECT_ID('dbo.AP_PaymentType', 'U') IS NOT NULL
            DELETE FROM AP_PaymentType WHERE Company = @cia;

        IF OBJECT_ID('dbo.ERP_Tax', 'U') IS NOT NULL
            DELETE FROM ERP_Tax WHERE Company = @cia;

        IF OBJECT_ID('dbo.AP_Document', 'U') IS NOT NULL
            DELETE FROM AP_Document WHERE Company = @cia;

        IF OBJECT_ID('dbo.ERP_CompanyType', 'U') IS NOT NULL
            DELETE FROM ERP_CompanyType WHERE Company = @cia;

        IF OBJECT_ID('dbo.SY_Parameter', 'U') IS NOT NULL
            DELETE FROM SY_Parameter WHERE Company = @cia;

        IF OBJECT_ID('dbo.SY_PersonCreditLimit', 'U') IS NOT NULL
            DELETE FROM SY_PersonCreditLimit WHERE Company = @cia;

        DELETE FROM SY_ObjectSecuence WHERE Company = @cia;
        DELETE FROM TE_CollectionForm WHERE Company = @cia;
        DELETE FROM TE_TransactionType WHERE Company = @cia;
        DELETE FROM AC_AccountLevel WHERE Company = @cia;
        DELETE FROM PR_mapping2 WHERE Company = @cia;
        DELETE FROM PR_Period WHERE Company = @cia;

        /* Persona RUC de la compañía (no empleados).
           Si otra CIA comparte el mismo RUC, NO borrar Person/PersonOffice. */
        IF @ruc <> ''
           AND NOT EXISTS (
                SELECT 1 FROM SY_Company
                WHERE LTRIM(RTRIM(ISNULL(RUC, ''))) = @ruc
                  AND Company <> @cia
           )
        BEGIN
            IF OBJECT_ID('dbo.AR_PersonProfile', 'U') IS NOT NULL
                DELETE FROM AR_PersonProfile WHERE person = @ruc;
            IF OBJECT_ID('dbo.PR_EmployeeLocal', 'U') IS NOT NULL
                DELETE FROM PR_EmployeeLocal
                WHERE Person = @ruc
                   OR EXISTS (
                        SELECT 1 FROM SY_PersonOffice po
                        WHERE po.PersonOffice = PR_EmployeeLocal.PersonOffice
                          AND po.Person = PR_EmployeeLocal.Person
                          AND po.Person = @ruc
                   );
            IF OBJECT_ID('dbo.SY_PersonOffice', 'U') IS NOT NULL
                DELETE FROM SY_PersonOffice WHERE person = @ruc;
            DELETE FROM SY_Person WHERE person = @ruc;
        END;

        DELETE FROM SY_Company WHERE Company = @cia;

        /* ===== Reactivar FKs ===== */
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_AFP';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ProcessType';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_AccountProfile';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_PayRollType';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Ocupation';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Parameter';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_FunctionParameter';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Concept';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ConceptGroup';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Formula';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Function';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_GroupSubroutine';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Subroutine';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ConceptSet';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ConceptSetDetail';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Report';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ReportSort';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ReportGroup';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ReportDetail';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ImportConcept';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ImportConceptDetail';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_LiquidationSection';
        EXEC Usp_Activa_Desactiva_Llaves '', 'SY_STREETTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'SY_ZONE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_LOCALTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_EMPLOYEESTATUS';
        EXEC Usp_Activa_Desactiva_Llaves '', 'SY_PERSONDOCUMENTTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_PERIODTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_PERIOD';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_CEASEREASON';
        EXEC Usp_Activa_Desactiva_Llaves '', 'SY_FAMILIYLINK';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_MEDICALRESTTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ACTIVITYTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_NACIONALIDAD';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_INSTRUCTIONLEVEL';
        EXEC Usp_Activa_Desactiva_Llaves '', 'HR_CONTRACTMODALITY';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_HEALTHENTITY';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_MODALITYFORMATIVE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_DEPENNACTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_RegimenLabour';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_EmployeeCategory';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_SCTR';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_SPECIALSTATUS';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_FATHERHOODDOC';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_EMPLOYEETYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_PENSIONTYPE';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_DriverLicenseType';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_LoanReason';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ProfessionalTraining';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_TYPEPROOF';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_LOCALCONDITION';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_SocialAssistanceCardType';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ProfessionalCategory';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_TaxAgreement';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_OccupationalGroup';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Mode';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_GenPensionType';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_IncomeType';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_AccountType';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ConceptAffect';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_WindowProcessGeneral';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_WindowProcess';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_WindowProcess_Order';
        EXEC Usp_Activa_Desactiva_Llaves '', 'PR_WindowProcess_Value';
        EXEC Usp_Activa_Desactiva_Llaves '', 'te_accounttype';
        EXEC Usp_Activa_Desactiva_Llaves '', 'erp_bank';
        EXEC Usp_Activa_Desactiva_Llaves '', 'AC_Account';
        EXEC Usp_Activa_Desactiva_Llaves '', 'te_bankaccount';
        EXEC Usp_Activa_Desactiva_Llaves '', 'SY_ApplicationPeriod';

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        /* Intentar reactivar FKs aunque falle el borrado */
        BEGIN TRY
            EXEC Usp_Activa_Desactiva_Llaves '', 'PR_Concept';
            EXEC Usp_Activa_Desactiva_Llaves '', 'PR_PayRollType';
            EXEC Usp_Activa_Desactiva_Llaves '', 'PR_ProcessType';
            EXEC Usp_Activa_Desactiva_Llaves '', 'PR_PERIOD';
        END TRY
        BEGIN CATCH
        END CATCH;

        DECLARE @errmsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @errsev INT = ERROR_SEVERITY();
        DECLARE @errsta INT = ERROR_STATE();
        RAISERROR(@errmsg, @errsev, @errsta);
    END CATCH
END
GO
