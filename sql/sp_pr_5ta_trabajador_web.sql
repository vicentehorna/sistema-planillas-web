/*
    Seguimiento de cálculo de 5ta categoría por trabajador.
    Usado por: POST /get_calculo_quinta_trabajador

    Parámetros:
      @company     — compañía
      @payrolltype — tipo de planilla
      @process     — tipo de proceso
      @period      — periodo (yyyymmdd)
      @person      — código trabajador
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_5ta_trabajador_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20),
    @process     VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @process = LTRIM(RTRIM(ISNULL(@process, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    SELECT DISTINCT
        CASE
            WHEN sy_person.lastname1 IS NULL THEN ''
            ELSE sy_person.lastname1
        END + ' ' +
        CASE
            WHEN sy_person.lastname2 IS NULL THEN ''
            ELSE sy_person.lastname2
        END + ' ' +
        CASE
            WHEN sy_person.name1 IS NULL THEN ''
            ELSE sy_person.name1
        END + ' ' +
        CASE
            WHEN sy_person.name2 IS NULL THEN ''
            ELSE sy_person.name2
        END AS name,
        (
            SELECT description
            FROM sy_persondocumenttype (NOLOCK)
            WHERE sy_persondocumenttype.PersonDocumentType = sy_person.employeedocumenttype
        ) + ':' AS documenttype,
        sy_person.documentnumber,
        (SELECT 12 - CONVERT(INT, SUBSTRING(@period, 5, 2))) AS meses_pendientes,
        (
            SELECT ParameterNumberValue * 7
            FROM PR_Parameter
            WHERE shortname = 'UIT' + SUBSTRING(@period, 1, 4)
              AND PR_Parameter.Company = @company
        ) AS uit,
        (
            SELECT ParameterNumberValue
            FROM PR_Parameter
            WHERE shortname = 'UIT' + SUBSTRING(@period, 1, 4)
              AND PR_Parameter.Company = @company
        ) AS par_uit,
        pr_employeepayroll.person,
        pr_employeepayroll.company,
        pr_employeepayroll.processtype,
        pr_employeepayroll.payrolltype,
        pr_position.description AS cargo,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'PROYECCION_RENTA'
              AND PERSON = pr_employee.person
        ) AS proy_ingresos,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'REM_ACUM_OTRA_EM'
              AND PERSON = pr_employee.person
        ) AS rem_otra_empresa,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'PROY_GRATI_JULIO'
              AND PERSON = pr_employee.person
        ) AS grati_julio,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'PROY_GRATI_DICIEMBRE'
              AND PERSON = pr_employee.person
        ) AS grati_dic,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'REM_ACUMULADA'
              AND PERSON = pr_employee.person
        ) AS rem_acumulada,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'TOTAL_REM_IMP_RENTA'
              AND PERSON = pr_employee.person
        ) AS ingresos_5ta,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'TOTAL5TAQUINCENA'
              AND PERSON = pr_employee.person
        ) AS otros_ingresos_5ta,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'RET_5TA_ACUMULADA'
              AND PERSON = pr_employee.person
        ) AS ret_anteriores,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'RENTA_ACUM_OTRA_EMP'
              AND PERSON = pr_employee.person
        ) AS ret_otra_empresa,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND SUBSTRING(PRPERIOD, 1, 6) = LEFT(@period, 6)
              AND pr_concept.formulacode = 'MESES'
              AND PERSON = pr_employee.person
        ) AS meses,
        CASE WHEN 1 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0101', @payrolltype, 'IN') END AS ingreso01,
        CASE WHEN 2 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0202', @payrolltype, 'IN') END AS ingreso02,
        CASE WHEN 3 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0303', @payrolltype, 'IN') END AS ingreso03,
        CASE WHEN 4 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0404', @payrolltype, 'IN') END AS ingreso04,
        CASE WHEN 5 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0505', @payrolltype, 'IN') END AS ingreso05,
        CASE WHEN 6 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0606', @payrolltype, 'IN') END AS ingreso06,
        CASE WHEN 7 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0707', @payrolltype, 'IN') END AS ingreso07,
        CASE WHEN 8 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0808', @payrolltype, 'IN') END AS ingreso08,
        CASE WHEN 9 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0909', @payrolltype, 'IN') END AS ingreso09,
        CASE WHEN 10 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1010', @payrolltype, 'IN') END AS ingreso10,
        CASE WHEN 11 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1111', @payrolltype, 'IN') END AS ingreso11,
        CASE WHEN 12 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1212', @payrolltype, 'IN') END AS ingreso12,
        CASE WHEN 1 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0101', @payrolltype, 'LI') END AS descuento01,
        CASE WHEN 2 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0202', @payrolltype, 'LI') END AS descuento02,
        CASE WHEN 3 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0303', @payrolltype, 'LI') END AS descuento03,
        CASE WHEN 4 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0404', @payrolltype, 'LI') END AS descuento04,
        CASE WHEN 5 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0505', @payrolltype, 'LI') END AS descuento05,
        CASE WHEN 6 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0606', @payrolltype, 'LI') END AS descuento06,
        CASE WHEN 7 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0707', @payrolltype, 'LI') END AS descuento07,
        CASE WHEN 8 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0808', @payrolltype, 'LI') END AS descuento08,
        CASE WHEN 9 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0909', @payrolltype, 'LI') END AS descuento09,
        CASE WHEN 10 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1010', @payrolltype, 'LI') END AS descuento10,
        CASE WHEN 11 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1111', @payrolltype, 'LI') END AS descuento11,
        CASE WHEN 12 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1212', @payrolltype, 'LI') END AS descuento12,
        CASE WHEN 1 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0101', @payrolltype, 'RE') END AS salida01,
        CASE WHEN 2 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0202', @payrolltype, 'RE') END AS salida02,
        CASE WHEN 3 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0303', @payrolltype, 'RE') END AS salida03,
        CASE WHEN 4 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0404', @payrolltype, 'RE') END AS salida04,
        CASE WHEN 5 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0505', @payrolltype, 'RE') END AS salida05,
        CASE WHEN 6 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0606', @payrolltype, 'RE') END AS salida06,
        CASE WHEN 7 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0707', @payrolltype, 'RE') END AS salida07,
        CASE WHEN 8 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0808', @payrolltype, 'RE') END AS salida08,
        CASE WHEN 9 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0909', @payrolltype, 'RE') END AS salida09,
        CASE WHEN 10 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1010', @payrolltype, 'RE') END AS salida10,
        CASE WHEN 11 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1111', @payrolltype, 'RE') END AS salida11,
        CASE WHEN 12 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1212', @payrolltype, 'RE') END AS salida12,
        CASE WHEN 1 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0101', @payrolltype, 'UT') END AS utilidad01,
        CASE WHEN 2 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0202', @payrolltype, 'UT') END AS utilidad02,
        CASE WHEN 3 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0303', @payrolltype, 'UT') END AS utilidad03,
        CASE WHEN 4 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0404', @payrolltype, 'UT') END AS utilidad04,
        CASE WHEN 5 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0505', @payrolltype, 'UT') END AS utilidad05,
        CASE WHEN 6 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0606', @payrolltype, 'UT') END AS utilidad06,
        CASE WHEN 7 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0707', @payrolltype, 'UT') END AS utilidad07,
        CASE WHEN 8 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0808', @payrolltype, 'UT') END AS utilidad08,
        CASE WHEN 9 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '0909', @payrolltype, 'UT') END AS utilidad09,
        CASE WHEN 10 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1010', @payrolltype, 'UT') END AS utilidad10,
        CASE WHEN 11 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1111', @payrolltype, 'UT') END AS utilidad11,
        CASE WHEN 12 >= CONVERT(INT, SUBSTRING(@period, 5, 2)) THEN 0 ELSE dbo.f_getSuma5ta_web(@company, @person, LEFT(@period, 4) + '1212', @payrolltype, 'UT') END AS utilidad12,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND PRPERIOD = @period
              AND pr_concept.formulacode = 'RET_RENTA_ACUM'
              AND PERSON = pr_employee.person
        ) AS ret_renta_acum,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND PRPERIOD = @period
              AND pr_concept.formulacode = 'DIFERENCIASEMANA'
              AND PERSON = pr_employee.person
        ) AS diferenciasemana,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND PRPERIOD = @period
              AND pr_concept.formulacode = 'NUMEROSEMANA'
              AND PERSON = pr_employee.person
        ) AS numerosemana,
        (
            SELECT SUM(ISNULL(CONCEPTVALUE, 0.00))
            FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
            WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @company
              AND pr_concept.COMPANY = @company
              AND pr_employeepayrollconcept.concept = pr_concept.concept
              AND PROCESSTYPE = @process
              AND PAYROLLTYPE = @payrolltype
              AND PRPERIOD = @period
              AND pr_concept.formulacode = 'TOTALDEV5TA'
              AND PERSON = pr_employee.person
        ) AS devolucion_quinta
    FROM pr_employee
        LEFT JOIN pr_employeecategory
            ON pr_employee.EmployeeCategory = pr_employeecategory.EmployeeCategory,
        sy_person
        LEFT JOIN sy_department
            ON sy_person.department = sy_department.department,
        sy_company,
        pr_payrolltype,
        pr_employeepayroll
        LEFT JOIN pr_position
            ON pr_employeepayroll.Position = pr_position.Position,
        PR_ProcessType,
        pr_mapping,
        pr_period,
        ac_costcenter,
        pr_periodtype
    WHERE pr_mapping.company = @company
      AND pr_employeepayroll.costcenter = ac_costcenter.costcenter
      AND pr_employee.company = pr_mapping.company
      AND pr_employee.Person = sy_person.Person
      AND pr_employee.Company = sy_company.Company
      AND pr_employeepayroll.PayRollType = pr_payrolltype.PayRollType
      AND pr_employeepayroll.Company = pr_employee.Company
      AND pr_employeepayroll.Person = pr_employee.Person
      AND pr_employeepayroll.ProcessType = PR_ProcessType.ProcessType
      AND pr_payrolltype.periodtype = pr_periodtype.periodtype
      AND pr_employeepayroll.processtype = @process
      AND pr_employeepayroll.payrolltype = @payrolltype
      AND LEFT(pr_employeepayroll.prperiod, 6) = LEFT(@period, 6)
      AND pr_employeepayroll.person = @person
      AND pr_period.payrolltype = @payrolltype
    ORDER BY 1 ASC;
END
GO
