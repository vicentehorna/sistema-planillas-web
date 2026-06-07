/*
    PLAME Archivo 18 (.rem) — Ingresos, tributos y descuentos del trabajador.

    Usado por: POST /api/plame/archivo-18/listado y generación TXT.

    Línea TXT: TipoDoc|NroDoc|PDT|Devengado|Pagado|
    Nombre archivo: 0601AAAAMMRRRRRRRRRRR.rem

    Basado en queries legacy PowerBuilder (listado de empleados + cálculo de conceptos).

    Parámetros:
      @cia         — compañía
      @period      — periodo tributario YYYYMM (6 dígitos)
      @payroll_all — Y = todas las planillas, N = filtrar por @payroll
      @payroll     — tipo de planilla (cuando @payroll_all = N)
      @cesados     — T = todos, Y = solo cesados, N = sin cese
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame18_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @cesados     CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    /* --- Empleados con conceptos en el periodo (rama principal) --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT pr_employee.person
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        INNER JOIN pr_concept (NOLOCK) ON 1 = 1
        INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
        INNER JOIN pr_employeepayrollconcept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
        INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        INNER JOIN pr_employeecategory (NOLOCK) ON pr_employee.employeecategory = pr_employeecategory.employeecategory
    WHERE sy_person.person = pr_employee.person
      AND pr_mapping.company = @cia
      AND pr_employee.employeecategory = pr_employeecategory.employeecategory
      AND pr_employeecategory.PDT = '1'
      AND pr_employeepayrollconcept.concept = pr_concept.concept
      AND pr_concepttype.concepttype = pr_concept.concepttype
      AND pr_concepttype.shortname IN ('I', 'A')
      AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
      AND pr_employeepayrollconcept.person = pr_employee.person
      AND pr_employeepayrollconcept.company = pr_employee.company
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND pr_employee.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND pr_employee.CeaseDate IS NULL)
      )
      AND pr_employeepayrollconcept.processtype IN (
            pr_mapping.CTSProcessType,
            pr_mapping.planillaprocess,
            pr_mapping.planillasemprocess,
            pr_mapping.VacationProcess,
            pr_mapping.liquidacionprocess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
      AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
      AND pr_concept.flagismonetary = 'Y'
      AND pr_concept.FLAGPAYROLLTICKET = 'Y'
      AND (
            (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') = 0
         OR (
                (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') > 0
                AND ISNULL(sy_person.isrecruiter, 'N') = 'N'
            )
      );

    /* --- Empleados con descanso médico >= 30 días sin TOTALINGRESO (rama legacy) --- */
    INSERT INTO #Empleados (person)
    SELECT A.person
    FROM PR_Employee A
        INNER JOIN SY_Person B ON A.Person = B.Person AND A.Status = 'N' AND A.Company = @cia
        LEFT JOIN sy_persondocumenttype S ON B.employeedocumenttype = S.persondocumenttype
        INNER JOIN PR_Mapping M ON A.Company = M.Company
    WHERE NOT EXISTS (
            SELECT 1
            FROM pr_employeepayrollconcept P
                INNER JOIN PR_Concept C ON P.Concept = C.Concept AND C.FormulaCode = 'TOTALINGRESO'
            WHERE P.Company = A.Company
              AND P.Person = A.Person
              AND LEFT(P.PRPeriod, 6) = @period
        )
      AND ISNULL((
            SELECT SUM(X.Days)
            FROM PR_EmployeeMedicalRest X
                INNER JOIN PR_MedicalRestType Y
                    ON X.person = A.person
                   AND X.MedicalRestType = Y.MedicalRestType
                   AND Y.pdt = '05'
                   AND LEFT(X.PRPeriod, 6) = @period
                   AND A.Company = @cia
        ), 0) >= 30
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll P
            WHERE P.Person = A.Person
              AND P.Company = A.Company
              AND LEFT(P.PRPeriod, 6) = @period
              AND P.ProcessType = M.CTSProcessType
        )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND A.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND A.CeaseDate IS NULL)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = A.person);

    CREATE TABLE #Conceptos (
        person          VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        pdt             VARCHAR(10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        conceptvalue    NUMERIC(19, 4) NOT NULL,
        conceptvaluelo  NUMERIC(19, 4) NOT NULL,
        PRIMARY KEY (person, pdt)
    );

    INSERT INTO #Conceptos (person, pdt, conceptvalue, conceptvaluelo)
    SELECT
        A.person,
        A.pdt,
        SUM(A.conceptvalue) AS conceptvalue,
        SUM(A.conceptvaluelo) AS conceptvaluelo
    FROM (
        SELECT
            pr_employee.person,
            LTRIM(RTRIM(pr_concept.pdt)) AS pdt,
            SUM(pr_employeepayrollconcept.conceptvaluelo) AS conceptvalue,
            SUM(pr_employeepayrollconcept.conceptvaluelo) AS conceptvaluelo
        FROM pr_employee (NOLOCK)
            INNER JOIN pr_employeepayrollconcept (NOLOCK)
                ON pr_employeepayrollconcept.person = pr_employee.person
               AND pr_employeepayrollconcept.company = pr_employee.company
            INNER JOIN pr_employeepayroll (NOLOCK)
                ON pr_employeepayrollconcept.company = pr_employeepayroll.company
               AND pr_employeepayrollconcept.person = pr_employeepayroll.person
               AND pr_employeepayrollconcept.payrolltype = pr_employeepayroll.payrolltype
               AND pr_employeepayrollconcept.processtype = pr_employeepayroll.processtype
               AND pr_employeepayrollconcept.prperiod = pr_employeepayroll.prperiod
            INNER JOIN pr_concept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
            INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
            INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        WHERE pr_mapping.company = @cia
          AND pr_mapping.company = pr_employee.company
          AND pr_employeepayrollconcept.concept = pr_concept.concept
          AND pr_concepttype.concepttype = pr_concept.concepttype
          AND pr_employeepayrollconcept.person = pr_employee.person
          AND pr_employeepayrollconcept.company = pr_employee.company
          AND (
                (SELECT COUNT(*) FROM pr_payrolltypeprocess WHERE company = @cia AND flagpdt = 'Y') = 0
             OR (
                    SELECT COUNT(*)
                    FROM pr_payrolltypeprocess
                    WHERE PayRollType = pr_employeepayrollconcept.PayRollType
                      AND ProcessType = pr_employeepayrollconcept.ProcessType
                      AND flagpdt = 'Y'
                ) > 0
          )
          AND NOT EXISTS (
                SELECT 1
                FROM pr_processtype
                WHERE ProcessType = pr_employeepayrollconcept.ProcessType
                  AND Company = @cia
                  AND ShortName = 'QUINCENA'
          )
          AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
          AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
          AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
          AND pr_concept.pdt IS NOT NULL
          AND LTRIM(RTRIM(pr_concept.pdt)) <> ''
          AND pr_concept.flagismonetary = 'Y'
          AND pr_concept.pdt NOT IN (
                '0100', '0200', '0300', '0400', '0500', '0600', '0603', '0604', '0607',
                '0610', '0700', '0800', '0802', '0804', '0806', '0808'
          )
          AND pr_employeepayrollconcept.processtype NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
          AND EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = pr_employee.person)
        GROUP BY pr_employee.person, pr_concept.pdt

        UNION ALL

        SELECT
            pr_employee.person,
            LTRIM(RTRIM(pr_concept.pdt)) AS pdt,
            0 AS conceptvalue,
            0 AS conceptvaluelo
        FROM pr_employee (NOLOCK)
            INNER JOIN pr_concept (NOLOCK) ON 1 = 1
            INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
            INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        WHERE pr_mapping.company = @cia
          AND pr_mapping.company = pr_employee.company
          AND sy_person.person = pr_employee.person
          AND pr_concept.pdt IS NOT NULL
          AND pr_concept.flagismonetary = 'Y'
          AND pr_concept.concept = pr_mapping.taxrentconcept
          AND (@payroll_all = 'Y' OR pr_employee.payrolltype = @payroll)
          AND EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = pr_employee.person)
        GROUP BY pr_employee.person, pr_concept.pdt
    ) A
    GROUP BY A.person, A.pdt
    HAVING SUM(A.conceptvaluelo) <> 0 OR SUM(A.conceptvalue) <> 0;

    SELECT
        C.person,
        CASE WHEN S.pdt = '03' THEN '04' ELSE S.pdt END AS documenttype,
        LTRIM(RTRIM(B.documentnumber)) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(B.lastname1, '') + ' ' +
            ISNULL(B.lastname2, '') + ' ' +
            ISNULL(B.name1, '') + ' ' +
            ISNULL(B.name2, '')
        )) AS name,
        LTRIM(RTRIM(C.pdt)) AS pdt,
        CAST(C.conceptvalue AS DECIMAL(19, 2)) AS conceptvalue,
        CAST(C.conceptvaluelo AS DECIMAL(19, 2)) AS conceptvaluelo,
        'N' AS selection
    FROM #Conceptos C
        INNER JOIN PR_Employee A ON A.Person = C.person AND A.Company = @cia
        INNER JOIN SY_Person B ON A.Person = B.Person
        LEFT JOIN sy_persondocumenttype S ON B.employeedocumenttype = S.persondocumenttype
    ORDER BY name ASC, C.pdt ASC;

    DROP TABLE #Conceptos;
    DROP TABLE #Empleados;
END
GO
