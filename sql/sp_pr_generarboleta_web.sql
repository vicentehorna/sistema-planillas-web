/*
    Generar boletas — cabecera y totales para el PDF.

    Usado por: generar_pdf_en_memoria (app.py).

    Parámetros:
      @cia, @process, @payrolltype, @period, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generarboleta_web]
    @cia         VARCHAR(4),
    @process     VARCHAR(20),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @currency CHAR(2);
    SET @currency = 'LO';

    SELECT DISTINCT
        CASE WHEN sy_person.lastname1 IS NULL THEN '' ELSE sy_person.lastname1 END + ' ' +
        CASE WHEN sy_person.lastname2 IS NULL THEN '' ELSE sy_person.lastname2 END + ' ' +
        CASE WHEN sy_person.name1 IS NULL THEN '' ELSE sy_person.name1 END + ' ' +
        CASE WHEN sy_person.name2 IS NULL THEN '' ELSE sy_person.name2 END AS nombre_trabajador,

        (SELECT MAX(pr_pensiontype.pdt)
         FROM PR_EmployeePayRoll AS E2
             INNER JOIN pr_pensiontype ON E2.pensiontype = pr_pensiontype.pensiontype
                                        AND E2.company = pr_pensiontype.company
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS TipoPension,

        (SELECT description
         FROM sy_persondocumenttype (NOLOCK)
         WHERE sy_persondocumenttype.PersonDocumentType = sy_person.employeedocumenttype) + ':' AS DocumentType,
        sy_person.documentnumber AS dni,

        /* ONP no tiene AFP: CASE expr WHEN NULL no funciona en SQL Server (NULL nunca iguala). */
        CASE
            WHEN ISNULL((
                SELECT MAX(Y.description)
                FROM PR_EmployeePayRoll E2
                    LEFT JOIN pr_afp Y ON E2.afp = Y.afp
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person
            ), '') = '' THEN 'SNP'
            ELSE (
                SELECT MAX(Y.description)
                FROM PR_EmployeePayRoll E2
                    LEFT JOIN pr_afp Y ON E2.afp = Y.afp
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person
            )
        END AS afp_description,

        CASE WHEN (
            (SELECT MAX(pr_pensiontype.pdt)
             FROM PR_EmployeePayRoll AS E2
                 INNER JOIN pr_pensiontype ON E2.pensiontype = pr_pensiontype.pensiontype
                                            AND E2.company = pr_pensiontype.company
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)) = '99'
        THEN 'NINGUNO'
        ELSE
            CASE
                WHEN ISNULL((
                    SELECT MAX(Y.description)
                    FROM PR_EmployeePayRoll E2
                        LEFT JOIN pr_afp Y ON E2.afp = Y.afp
                    WHERE E2.COMPANY = @cia
                      AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                      AND E2.processtype = @process
                      AND E2.PRPERIOD = @period
                      AND E2.PERSON = SY_Person.Person
                ), '') = '' THEN 'SNP'
                ELSE (
                    SELECT MAX(Y.description)
                    FROM PR_EmployeePayRoll E2
                        LEFT JOIN pr_afp Y ON E2.afp = Y.afp
                    WHERE E2.COMPANY = @cia
                      AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                      AND E2.processtype = @process
                      AND E2.PRPERIOD = @period
                      AND E2.PERSON = SY_Person.Person
                )
            END
        END AS regimenpension,

        (SELECT MAX(E2.afpcard)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS cupss,
        pr_employee.socialassistancenumber,
        pr_employeepayroll.person,

        (SELECT SUM(ISNULL(E2.salary, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS rem_basica,

        (SELECT MAX(E2.costcentername)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS cccode,

        (SELECT SUM(ISNULL(E2.vacationdays, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS vacationdays,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.totalincomelo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.totalincomeex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS total_ingresos,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.totaldebitslo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.totaldebitsex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS total_egresos,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.totalpatronallo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.totalpatronalex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS total_aportes,

        (SELECT SUM(ISNULL(E2.absencesdays, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS absencesday,

        ISNULL((SELECT SUM(ISNULL(E2.conceptvalue, 0))
                FROM pr_employeepayrollconcept AS E2
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.Concept IN (SELECT mrallowancedaysnotaxconcept FROM PR_Mapping2 WHERE PR_Mapping2.company = @cia)
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person), 0) AS medicalrestdays,

        ISNULL((SELECT SUM(ISNULL(E2.conceptvalue, 0))
                FROM pr_employeepayrollconcept AS E2
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.Concept IN (SELECT mrallowancedaystaxconcept FROM PR_Mapping2 WHERE PR_Mapping2.company = @cia)
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person), 0) AS maternidad,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode IN (
               'DIAS_DESC_SUBSI_AFEC',
               'DIAS_DESC_SUBSI_INAF',
               'DIAS_SUBSIDIO'
           )
           AND PERSON = pr_employee.Person) AS dias_subsidio,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.netlo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.netex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS neto_pagar,

        sy_company.description AS nombre_empresa,
        sy_company.ruc AS ruc_empresa,
        sy_company.address AS direccion_empresa,
        'DS. 001-98-TR' AS decreto_empresa,
        sy_company.telephone AS telefono_empresa,
        sy_company.Rep_Position AS cargo_representante,
        sy_company.Representative AS nombre_representante,
        sy_person.email AS correo_trabajador,
        (SELECT description
         FROM PR_EmployeeCategory (NOLOCK)
         WHERE pr_employee.employeecategory = PR_EmployeeCategory.employeecategory) AS CategoryDescription,
        pr_employee.employeecategory,
        pr_employee.employeecode,

        (SELECT MAX(ISNULL(E2.position, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS position,
        pr_payrolltype.title,
        pr_employeecategory.description,

        (SELECT MAX(ISNULL(P.description, 0))
         FROM PR_EmployeePayRoll AS E2
             LEFT JOIN pr_position P ON E2.position = P.position
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS cargo_trabajador,

        (SELECT MAX(E2.ceasedate)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS fecha_cese,

        (SELECT MAX(E2.entrydate)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS fecha_ingreso,
        PR_ProcessType.description AS process,
        PR_ProcessType.ShortName AS process_shortname,
        pr_period.datebegin,
        pr_period.dateend,
        pr_period.cadatebegin,
        pr_period.cadateend,
        pr_periodtype.description,
        sy_department.name,
        sy_person.birthdate,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_DESCANSO_EMPRES'
           AND PERSON = pr_employee.Person) AS dias_no_subsidiados,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_PATERNIDAD'
           AND PERSON = pr_employee.Person) AS dias_paternidad,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAFALLECIMIENTO'
           AND PERSON = pr_employee.Person) AS dias_fallecimiento,

        CASE
            WHEN ISNULL((
                SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
                FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
                WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
                  AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
                  AND PROCESSTYPE = @process
                  AND PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND PRPERIOD = @period
                  AND pr_concept.formulacode = 'REM_ACUM_OTRA_EM'
                  AND PERSON = pr_employee.Person
            ), 0) <> 0 THEN 'Si'
            ELSE 'No'
        END AS otros_empleadores_5ta,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) <> '02' THEN
            CASE WHEN (SELECT COUNT(*)
                       FROM PR_EmployeeConcept
                       WHERE Person = pr_employee.person
                         AND PayRollType = @payrolltype
                         AND EXISTS (SELECT *
                                     FROM PR_Concept
                                     WHERE Concept = PR_EmployeeConcept.Concept
                                       AND formulacode = 'AFP_FLUJO')) > 0
            THEN 'MIXTO' ELSE 'FLUJO' END
        ELSE '' END AS tipocomision,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'JOR_DIARIO'
           AND PERSON = pr_employee.Person) AS jornal,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_VACAC_NORMAL'
           AND PERSON = pr_employee.Person) AS dias_vacaciones,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'C_HORASTRABAJADAS'
           AND PERSON = pr_employee.Person) AS horassemana,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_100'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_100,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_25'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_25,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_35'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_35,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_60'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_60,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_NOC'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_NOC,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'REM_BASICA'
           AND PERSON = pr_employee.Person) AS salaryconcept,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'SUELDOBASICO'
           AND PERSON = pr_employee.Person) AS sueldobasico,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'FALTAS_EMPRE'
           AND PERSON = pr_employee.Person) AS dias_no_laborados,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_PAGADOS'
           AND PERSON = pr_employee.Person) AS dias_laborables,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_DIAS_AUSENCIA'
           AND PERSON = pr_employee.Person) AS dias_faltas_injustif,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_LIC_SINGOCE'
           AND PERSON = pr_employee.Person) AS diassingoce,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_LICENCIA_GOCE'
           AND PERSON = pr_employee.Person) AS diascongoce,

        (SELECT PR_EMPLOYEEPAYROLLCONCEPT.CONCEPTVALUE
         FROM PR_EMPLOYEEPAYROLLCONCEPT
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PR_EMPLOYEEPAYROLLCONCEPT.PROCESSTYPE = @process
           AND PR_EMPLOYEEPAYROLLCONCEPT.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PR_EMPLOYEEPAYROLLCONCEPT.PRPERIOD = @period
           AND PR_EMPLOYEEPAYROLLCONCEPT.CONCEPT = pr_mapping.sundaydaysworkconcept
           AND PR_EMPLOYEEPAYROLLCONCEPT.PERSON = pr_employee.Person) AS Sunday_days_work,
        pr_employee.SalaryAccount AS numerocuenta,
        (SELECT name FROM erp_bank WHERE bank = pr_employee.salarybank) AS bancosalario,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 22, 23, 24, 25)
        THEN (SELECT PensionPercentage FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS aporte,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 22, 23, 24, 25)
        THEN (SELECT VariablePercentage FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS comisionflujo,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 22, 23, 24, 25)
        THEN (SELECT InsuredPercentage FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS seguro,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) = 2
        THEN 13 ELSE 0 END AS snp,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 23, 24, 25)
        THEN (SELECT FixedAmount FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS comisionmixta,

        (SELECT Description FROM PR_SpecialStatus WHERE SpecialStatus = pr_employee.SpecialStatus) AS clasificacion,

        /* Título según el @process solicitado (no depende del join ambiguo). */
        CASE WHEN UPPER(LTRIM(RTRIM(ISNULL((
                SELECT TOP 1 pt.ShortName
                FROM PR_ProcessType pt (NOLOCK)
                WHERE pt.ProcessType = @process
                  AND (pt.Company = @cia OR pt.Company IS NULL)
                ORDER BY CASE WHEN pt.Company = @cia THEN 0 ELSE 1 END
            ), '')))) = 'GRATIFICACION' THEN
            'BOLETA DE GRATIFICACION - '
        ELSE
            'BOLETA DE PAGO ' + UPPER(LTRIM(RTRIM(ISNULL(pr_periodtype.description, '')))) + ' - '
        END +
        UPPER(
            CASE SUBSTRING(@period, 5, 2)
                WHEN '01' THEN 'Enero'
                WHEN '02' THEN 'Febrero'
                WHEN '03' THEN 'Marzo'
                WHEN '04' THEN 'Abril'
                WHEN '05' THEN 'Mayo'
                WHEN '06' THEN 'Junio'
                WHEN '07' THEN 'Julio'
                WHEN '08' THEN 'Agosto'
                WHEN '09' THEN 'Setiembre'
                WHEN '10' THEN 'Octubre'
                WHEN '11' THEN 'Noviembre'
                WHEN '12' THEN 'Diciembre'
                ELSE SUBSTRING(@period, 5, 2)
            END
        ) + ' ' + LEFT(@period, 4) AS titulo_boleta,

        'Del ' + CONVERT(VARCHAR(10), pr_period.cadatebegin, 103)
            + ' al ' + CONVERT(VARCHAR(10), pr_period.cadateend, 103) AS RangoFechas

    FROM pr_employee
        LEFT JOIN pr_employeecategory ON pr_employee.EmployeeCategory = pr_employeecategory.EmployeeCategory,
         sy_person
        LEFT JOIN sy_department ON sy_person.department = sy_department.department,
         sy_company,
         pr_payrolltype,
         pr_employeepayroll
        LEFT JOIN pr_position ON pr_employeepayroll.Position = pr_position.Position,
         PR_ProcessType,
         pr_mapping,
         pr_period,
         ac_costcenter,
         pr_periodtype
    WHERE pr_mapping.company = @cia
      AND pr_employeepayroll.costcenter = ac_costcenter.costcenter
      AND pr_employee.company = pr_mapping.company
      AND pr_employee.Person = sy_person.Person
      AND pr_employee.Company = sy_company.Company
      AND pr_employeepayroll.PayRollType = pr_payrolltype.PayRollType
      AND pr_employeepayroll.Company = pr_employee.Company
      AND pr_employeepayroll.Person = pr_employee.Person
      AND pr_employeepayroll.ProcessType = PR_ProcessType.ProcessType
      AND PR_ProcessType.Company = @cia
      AND pr_employeepayroll.processtype = @process
      AND pr_employeepayroll.payrolltype = @payrolltype
      AND pr_payrolltype.periodtype = pr_periodtype.periodtype
      AND pr_employeepayroll.prperiod = @period
      AND pr_employeepayroll.person = @person
      AND pr_period.company = @cia
      AND pr_period.payrolltype = @payrolltype
      AND pr_period.prperiod = @period;
END
GO
