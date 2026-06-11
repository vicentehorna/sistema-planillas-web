/*
    Declaración AFP — reporte analítico RPR004 Planilla de AFP (AFPnet).

    Usado por: POST /api/declaracion-afp/listado y /api/declaracion-afp/generar-xlsx

    Basado en: AUXILIARES/REPORTE AFPNET.txt (DataWindow PowerBuilder).

    Parámetros:
      @cia              — compañía
      @period           — periodo YYYYMM (6 dígitos)
      @payroll_all      — Y = todas las planillas, N = filtrar por @payroll
      @payroll          — tipo de planilla
      @afp_all          — Y = todas las AFP, N = filtrar por @afp
      @afp              — código AFP
      @repunit_all      — Y = todas las unidades de replicación
      @repunit          — unidad de replicación
      @flagcostcenter   — Y = todos los centros de costo, N = filtrar por @costcenter
      @costcenter       — centro de costo
      @employee_all     — Y = todos los trabajadores, N = filtrar por @employee
      @employee         — código persona
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_declaracion_afp_web]
    @cia              VARCHAR(10),
    @period           VARCHAR(20),
    @payroll_all      CHAR(1)     = 'Y',
    @payroll          VARCHAR(20) = NULL,
    @afp_all          CHAR(1)     = 'Y',
    @afp              VARCHAR(20) = NULL,
    @repunit_all      CHAR(1)     = 'Y',
    @repunit          VARCHAR(4)  = NULL,
    @flagcostcenter   CHAR(1)     = 'Y',
    @costcenter       VARCHAR(20) = NULL,
    @employee_all     CHAR(1)     = 'Y',
    @employee         VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @afp_all = UPPER(LTRIM(RTRIM(ISNULL(@afp_all, 'Y'))));
    SET @afp = LTRIM(RTRIM(ISNULL(@afp, '')));
    SET @repunit_all = UPPER(LTRIM(RTRIM(ISNULL(@repunit_all, 'Y'))));
    SET @repunit = LTRIM(RTRIM(ISNULL(@repunit, '')));
    SET @flagcostcenter = UPPER(LTRIM(RTRIM(ISNULL(@flagcostcenter, 'Y'))));
    SET @costcenter = LTRIM(RTRIM(ISNULL(@costcenter, '')));
    SET @employee_all = UPPER(LTRIM(RTRIM(ISNULL(@employee_all, 'Y'))));
    SET @employee = LTRIM(RTRIM(ISNULL(@employee, '')));

    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @afp_all NOT IN ('Y', 'N') SET @afp_all = 'Y';
    IF @repunit_all NOT IN ('Y', 'N') SET @repunit_all = 'Y';
    IF @flagcostcenter NOT IN ('Y', 'N') SET @flagcostcenter = 'Y';
    IF @employee_all NOT IN ('Y', 'N') SET @employee_all = 'Y';

    SELECT
        E.person,
        LTRIM(RTRIM(ISNULL(F.description, ''))) AS afp_description,
        LTRIM(RTRIM(ISNULL(A.afpcard, ''))) AS cuspp,
        LTRIM(RTRIM(ISNULL(P.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(P.lastname1, ''))) AS lastname1,
        LTRIM(RTRIM(ISNULL(P.lastname2, ''))) AS lastname2,
        LTRIM(RTRIM(ISNULL(P.name1, '') + ' ' + ISNULL(P.name2, ''))) AS names,
        CASE
            WHEN CONVERT(VARCHAR(4), YEAR(ISNULL(E.ceasedate, ISNULL(E.reentrydate, E.entrydate))))
                 + RIGHT('00' + CONVERT(VARCHAR(2), MONTH(ISNULL(E.ceasedate, ISNULL(E.reentrydate, E.entrydate)))), 2) <> LEFT(A.prperiod, 6)
            THEN ''
            ELSE CASE
                WHEN ISNULL(E.ceasedate, '') = '' THEN '01 ' + CONVERT(CHAR(10), ISNULL(E.reentrydate, E.entrydate), 103)
                ELSE '02 ' + CONVERT(CHAR(10), E.ceasedate, 103)
            END
        END AS fecha_cese,
        CASE
            WHEN ISNULL(E.reentrydate, E.entrydate) IS NULL THEN ''
            ELSE CONVERT(CHAR(10), ISNULL(E.reentrydate, E.entrydate), 103)
        END AS entrydate,
        CASE
            WHEN ISNULL(E.ceasedate, '') = '' THEN ''
            ELSE CONVERT(CHAR(10), E.ceasedate, 103)
        END AS ceasedate,
        CASE
            WHEN E.reentrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.reentrydate, 112), 6) = @period THEN 'S'
            WHEN E.reentrydate IS NULL
             AND E.entrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.entrydate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS inicio_relacion,
        CASE
            WHEN E.ceasedate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.ceasedate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS cese_relacion,
        CASE
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN 'L'
            ELSE ''
        END AS excepcion_aportar,
        CASE
            WHEN CAST(ISNULL(A.assureableremamountlo, 0) AS DECIMAL(19, 2)) > 0 THEN 'S'
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN 'S'
            WHEN E.reentrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.reentrydate, 112), 6) = @period THEN 'S'
            WHEN E.reentrydate IS NULL
             AND E.entrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.entrydate, 112), 6) = @period THEN 'S'
            WHEN E.ceasedate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.ceasedate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS relacion_laboral,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept EC (NOLOCK)
                    INNER JOIN PR_Concept C2 (NOLOCK)
                        ON EC.Concept = C2.Concept
                       AND C2.Company = @cia
                WHERE EC.Person = E.person
                  AND EC.PayRollType = E.payrolltype
                  AND EC.Company = @cia
                  AND C2.FormulaCode = 'FLAG_MINERO'
            ) THEN 'M'
            ELSE 'N'
        END AS tipo_trabajo,
        CASE
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN CAST(0 AS DECIMAL(19, 2))
            ELSE CAST(ISNULL(A.assureableremamountlo, 0) AS DECIMAL(19, 2))
        END AS remuneracion,
        CAST(ISNULL(F.TopAFP, 0) AS DECIMAL(19, 2)) AS topafp,
        CAST(ISNULL(F.InsuredPercentage, 0) AS DECIMAL(19, 4)) AS insuredpercentage,
        CAST(ISNULL(A.fixedamountlo, 0) AS DECIMAL(19, 2)) AS aporte_obligatorio,
        CAST(ISNULL(A.variableamountlo, 0) AS DECIMAL(19, 2)) AS aporte_empleador,
        CAST(ISNULL(A.fixedamountlo, 0) + ISNULL(A.variableamountlo, 0) AS DECIMAL(19, 2)) AS total_fondo_pensiones,
        CAST(ISNULL(A.insuredamountlo, 0) AS DECIMAL(19, 2)) AS seguro,
        CAST(ROUND(
            (
                CASE
                    WHEN ISNULL(F.TopAFP, 0) > 0 AND ISNULL(A.assureableremamountlo, 0) > ISNULL(F.TopAFP, 0)
                        THEN F.TopAFP
                    ELSE ISNULL(A.assureableremamountlo, 0)
                END
            ) * ISNULL(F.InsuredPercentage, 0) / 100.0,
        2) AS DECIMAL(19, 2)) AS seguro_esperado,
        CAST(ISNULL(A.arcomisionamountlo, 0) AS DECIMAL(19, 2)) AS comision,
        CAST(ISNULL(A.insuredamountlo, 0) + ISNULL(A.arcomisionamountlo, 0) AS DECIMAL(19, 2)) AS total_retenciones,
        CAST(ISNULL((
            SELECT CONCEPTVALUE
            FROM PR_EMPLOYEEPAYROLLCONCEPT X (NOLOCK)
                INNER JOIN PR_Concept Y (NOLOCK) ON X.Concept = Y.Concept
            WHERE X.COMPANY = @cia
              AND Y.COMPANY = @cia
              AND X.concept = Y.concept
              AND X.PROCESSTYPE = (
                    SELECT processtype
                    FROM pr_processtype (NOLOCK)
                    WHERE shortname = 'FIN_DE_MES'
                      AND company = @cia
                )
              AND X.PAYROLLTYPE = E.payrolltype
              AND LEFT(X.PRPERIOD, 6) = @period
              AND Y.formulacode = 'AFP2APORTE'
              AND X.PERSON = E.person
        ), 0) AS DECIMAL(19, 2)) AS aporte_riesgo_trab,
        ISNULL((
            SELECT CASE LTRIM(RTRIM(ISNULL(S.pdt, '')))
                WHEN '01' THEN '0'
                WHEN '04' THEN '1'
                WHEN '02' THEN '2'
                WHEN '03' THEN '2'
                WHEN '13' THEN '3'
                WHEN '11' THEN '3'
                WHEN '07' THEN '4'
                ELSE '0'
            END
            FROM sy_persondocumenttype S (NOLOCK)
            WHERE S.PersonDocumentType = P.employeedocumenttype
        ), '0') AS tipodoc
    FROM PR_EmployeeAFP A (NOLOCK)
        INNER JOIN PR_EmployeeAFPHeader H (NOLOCK)
            ON H.company = A.company
           AND H.prperiod = A.prperiod
           AND H.afp = A.afp
           AND H.replicationunit = A.replicationunit
           AND H.costcenter = A.costcenter
           AND H.payrolltype = A.payrolltype
        INNER JOIN PR_AFP F (NOLOCK) ON A.afp = F.afp
        INNER JOIN sy_person P (NOLOCK) ON A.person = P.person
        INNER JOIN pr_employee E (NOLOCK)
            ON A.person = E.person
           AND A.company = E.company
        INNER JOIN sy_company C (NOLOCK) ON A.company = C.company
    WHERE A.company = @cia
      AND LEFT(A.prperiod, 6) = @period
      AND (@payroll_all = 'Y' OR H.payrolltype = @payroll)
      AND (@afp_all = 'Y' OR A.afp = @afp)
      AND (@repunit_all = 'Y' OR H.replicationunit = @repunit)
      AND (@flagcostcenter = 'Y' OR H.costcenter = @costcenter)
      AND (@employee_all = 'Y' OR A.person = @employee)

    UNION ALL

    /* Jubilados: PR_EmployeeConcept con FLAG_JUBILADO (legacy UNION ALL AFPnet). */
    SELECT
        E.person,
        '(Jubilado)' AS afp_description,
        LTRIM(RTRIM(ISNULL(E.AFPCard, ''))) AS cuspp,
        LTRIM(RTRIM(ISNULL(P.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(P.lastname1, ''))) AS lastname1,
        LTRIM(RTRIM(ISNULL(P.lastname2, ''))) AS lastname2,
        LTRIM(RTRIM(ISNULL(P.name1, '') + ' ' + ISNULL(P.name2, ''))) AS names,
        '' AS fecha_cese,
        CASE WHEN E.entrydate IS NULL THEN '' ELSE CONVERT(CHAR(10), E.entrydate, 103) END AS entrydate,
        CASE WHEN ISNULL(E.ceasedate, '') = '' THEN '' ELSE CONVERT(CHAR(10), E.ceasedate, 103) END AS ceasedate,
        'N' AS inicio_relacion,
        'N' AS cese_relacion,
        CASE
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN 'L'
            ELSE 'J'
        END AS excepcion_aportar,
        'S' AS relacion_laboral,
        'N' AS tipo_trabajo,
        CAST(0 AS DECIMAL(19, 2)) AS remuneracion,
        CAST(0 AS DECIMAL(19, 2)) AS topafp,
        CAST(0 AS DECIMAL(19, 4)) AS insuredpercentage,
        CAST(0 AS DECIMAL(19, 2)) AS aporte_obligatorio,
        CAST(0 AS DECIMAL(19, 2)) AS aporte_empleador,
        CAST(0 AS DECIMAL(19, 2)) AS total_fondo_pensiones,
        CAST(0 AS DECIMAL(19, 2)) AS seguro,
        CAST(0 AS DECIMAL(19, 2)) AS seguro_esperado,
        CAST(0 AS DECIMAL(19, 2)) AS comision,
        CAST(0 AS DECIMAL(19, 2)) AS total_retenciones,
        CAST(0 AS DECIMAL(19, 2)) AS aporte_riesgo_trab,
        ISNULL((
            SELECT CASE LTRIM(RTRIM(ISNULL(S.pdt, '')))
                WHEN '01' THEN '0'
                WHEN '04' THEN '1'
                WHEN '02' THEN '2'
                WHEN '03' THEN '2'
                WHEN '13' THEN '3'
                WHEN '11' THEN '3'
                WHEN '07' THEN '4'
                ELSE '0'
            END
            FROM sy_persondocumenttype S (NOLOCK)
            WHERE S.PersonDocumentType = P.employeedocumenttype
        ), '0') AS tipodoc
    FROM PR_EmployeeConcept EC (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK)
            ON EC.Person = E.Person
           AND EC.Company = E.Company
        INNER JOIN PR_Concept C (NOLOCK)
            ON EC.Concept = C.Concept
           AND C.Company = @cia
        INNER JOIN sy_person P (NOLOCK)
            ON EC.Person = P.person
    WHERE EC.Company = @cia
      AND C.FormulaCode = 'FLAG_JUBILADO'
      AND EC.FlagFrecuencyType IN ('P', 'T')
      AND (
            EC.FlagFrecuencyType = 'P'
            OR (EC.FlagFrecuencyType = 'T' AND LEFT(EC.PRPeriodStart, 6) = @period)
          )
      AND (@payroll_all = 'Y' OR EC.PayRollType = @payroll)
      AND (@employee_all = 'Y' OR EC.Person = @employee)
      AND ISNULL(LTRIM(RTRIM(E.AFP)), '') <> ''
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeeAFP A2 (NOLOCK)
            WHERE A2.person = EC.Person
              AND A2.company = @cia
              AND LEFT(A2.prperiod, 6) = @period
      )

    ORDER BY afp_description, lastname1;
END
GO
