/*
    PLAME Archivo 18 — Validaciones de incidencias (código PDT y cantidad de trabajadores).

    Usado por: POST /api/plame/archivo-18/listado

    Reglas:
      - Conceptos I, D y A con movimiento en el periodo deben tener código PDT
        (excepto descuento ONP y aporte ESSALUD).
      - Cantidad de trabajadores distintos del Archivo 18 (#Empleados activos en el periodo)
        = trabajadores distintos en planilla activa del periodo.
      - El filtro de vigencia en el periodo solo aplica a la comparacion; el listado no cambia.

    Parámetros: mismos que sp_pr_listado_plame18_web.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_archivo18_web]
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

    DECLARE @fecha_inicio_mes DATE;
    DECLARE @fecha_fin_mes DATE;
    DECLARE @period_ym CHAR(6);

    SET @period_ym = LEFT(@period, 6);
    IF LEN(@period_ym) = 6 AND @period_ym NOT LIKE '%[^0-9]%'
    BEGIN
        SET @fecha_inicio_mes = CONVERT(DATE, @period_ym + '01', 112);
        SET @fecha_fin_mes = EOMONTH(@fecha_inicio_mes);
    END;

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    CREATE TABLE #msg (
        person  VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        mensaje VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    );

    /* --- Misma población que sp_pr_listado_plame18_web --- */
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

    /* --- Conceptos I / D / A sin código PDT (excepto ONP y ESSALUD) --- */
    INSERT INTO #msg (person, mensaje)
    SELECT
        NULL,
        CASE T.ShortName
            WHEN 'I' THEN 'Concepto ingreso sin código PDT: '
            WHEN 'D' THEN 'Concepto descuento sin código PDT: '
            ELSE 'Concepto aporte sin código PDT: '
        END + T.Description
    FROM (
        SELECT DISTINCT CT.ShortName, C.Description
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept
            INNER JOIN PR_ConceptType CT (NOLOCK) ON C.ConceptType = CT.ConceptType
            INNER JOIN PR_Employee E (NOLOCK)
                ON EPC.Company = E.Company
               AND EPC.Person = E.Person
            INNER JOIN PR_EmployeeCategory EC (NOLOCK) ON E.EmployeeCategory = EC.EmployeeCategory
            INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EPC.Company
            INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
        WHERE EPC.Company = @cia
          AND LEFT(EPC.PRPeriod, 6) = @period
          AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
          AND CT.ShortName IN ('I', 'D', 'A')
          AND C.FlagIsMonetary = 'Y'
          AND EPC.ConceptValueLo IS NOT NULL
          AND ABS(EPC.ConceptValueLo) >= 0.005
          AND ISNULL(LTRIM(RTRIM(C.PDT)), '') = ''
          AND NOT (CT.ShortName = 'D' AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'ONP')
          AND NOT (
                CT.ShortName = 'A'
                AND (
                    UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) LIKE '%ESSALUD%'
                    OR UPPER(C.Description) LIKE '%ESSALUD%'
                )
          )
          AND EC.PDT = '1'
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND E.CeaseDate IS NULL)
          )
          AND (
                (SELECT COUNT(*) FROM SY_Company WHERE Company = @cia AND Description LIKE '%PLANINVES%') = 0
             OR ISNULL(SP.IsRecruiter, 'N') = 'N'
          )
          AND EPC.ProcessType IN (
                M.CTSProcessType,
                M.PlanillaProcess,
                M.PlanillaSemProcess,
                M.VacationProcess,
                M.LiquidacionProcess,
                (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
          )
          AND NOT EXISTS (
                SELECT 1
                FROM PR_ProcessType PT
                WHERE PT.ProcessType = EPC.ProcessType
                  AND PT.Company = @cia
                  AND PT.ShortName = 'QUINCENA'
          )
          AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
    ) T;

    /* --- Cantidad de trabajadores distintos: Archivo 18 vs planilla (activos en el periodo) --- */
    DECLARE @cnt_archivo18 INT;
    DECLARE @cnt_planilla INT;

    SELECT @cnt_archivo18 = COUNT(DISTINCT EM.person)
    FROM #Empleados EM
        INNER JOIN PR_Employee E (NOLOCK) ON E.Company = @cia AND E.Person = EM.person
    WHERE (
            @fecha_fin_mes IS NULL
         OR (
                CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                AND (
                    E.CeaseDate IS NULL
                    OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                )
            )
      );

    SELECT @cnt_planilla = COUNT(DISTINCT EP.Person)
    FROM PR_EmployeePayRoll EP (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK) ON E.Company = EP.Company AND E.Person = EP.Person
        INNER JOIN PR_EmployeeCategory EC (NOLOCK) ON E.EmployeeCategory = EC.EmployeeCategory
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EP.Company
        INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND EC.PDT = '1'
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND EP.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND (
            @fecha_fin_mes IS NULL
         OR (
                CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                AND (
                    E.CeaseDate IS NULL
                    OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                )
            )
      )
      AND (
            (SELECT COUNT(*) FROM SY_Company WHERE Company = @cia AND Description LIKE '%PLANINVES%') = 0
         OR ISNULL(SP.IsRecruiter, 'N') = 'N'
      );

    IF @cnt_archivo18 <> @cnt_planilla
    BEGIN
        INSERT INTO #msg (person, mensaje)
        VALUES (
            NULL,
            'Cantidad de trabajadores no coincide: Archivo 18 tiene '
            + CAST(@cnt_archivo18 AS VARCHAR(10))
            + ', planilla tiene '
            + CAST(@cnt_planilla AS VARCHAR(10)) + '.'
        );

        INSERT INTO #msg (person, mensaje)
        SELECT
            EP.Person,
            'Trabajador en planilla no incluido en Archivo 18: '
            + LTRIM(RTRIM(
                ISNULL(SP.LastName1, '') + ' ' +
                ISNULL(SP.LastName2, '') + ' ' +
                ISNULL(SP.Name1, '') + ' ' +
                ISNULL(SP.Name2, '')
            ))
            + ' (DNI '
            + LTRIM(RTRIM(ISNULL(SP.DocumentNumber, '')))
            + ')'
        FROM PR_EmployeePayRoll EP (NOLOCK)
            INNER JOIN PR_Employee E (NOLOCK) ON E.Company = EP.Company AND E.Person = EP.Person
            INNER JOIN PR_EmployeeCategory EC (NOLOCK) ON E.EmployeeCategory = EC.EmployeeCategory
            INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EP.Company
            INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
        WHERE EP.Company = @cia
          AND LEFT(EP.PRPeriod, 6) = @period
          AND EC.PDT = '1'
          AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
          AND EP.ProcessType IN (
                M.CTSProcessType,
                M.PlanillaProcess,
                M.PlanillaSemProcess,
                M.VacationProcess,
                M.LiquidacionProcess,
                (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
          )
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND E.CeaseDate IS NULL)
          )
          AND (
                @fecha_fin_mes IS NULL
             OR (
                    CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                    AND (
                        E.CeaseDate IS NULL
                        OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                    )
                )
          )
          AND (
                (SELECT COUNT(*) FROM SY_Company WHERE Company = @cia AND Description LIKE '%PLANINVES%') = 0
             OR ISNULL(SP.IsRecruiter, 'N') = 'N'
          )
          AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EP.Person);

        INSERT INTO #msg (person, mensaje)
        SELECT
            EM.person,
            'Trabajador en Archivo 18 no encontrado en planilla del periodo: '
            + LTRIM(RTRIM(
                ISNULL(SP.LastName1, '') + ' ' +
                ISNULL(SP.LastName2, '') + ' ' +
                ISNULL(SP.Name1, '') + ' ' +
                ISNULL(SP.Name2, '')
            ))
            + ' (DNI '
            + LTRIM(RTRIM(ISNULL(SP.DocumentNumber, '')))
            + ')'
        FROM #Empleados EM
            INNER JOIN PR_Employee E (NOLOCK) ON E.Company = @cia AND E.Person = EM.person
            INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
        WHERE (
                @fecha_fin_mes IS NULL
             OR (
                    CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                    AND (
                        E.CeaseDate IS NULL
                        OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                    )
                )
          )
          AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll EP (NOLOCK)
                INNER JOIN PR_Employee EP_E (NOLOCK)
                    ON EP_E.Company = EP.Company
                   AND EP_E.Person = EP.Person
                INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EP.Company
            WHERE EP.Company = @cia
              AND EP.Person = EM.person
              AND LEFT(EP.PRPeriod, 6) = @period
              AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
              AND EP.ProcessType IN (
                    M.CTSProcessType,
                    M.PlanillaProcess,
                    M.PlanillaSemProcess,
                    M.VacationProcess,
                    M.LiquidacionProcess,
                    (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
              )
              AND (
                    @fecha_fin_mes IS NULL
                 OR (
                        CONVERT(DATE, ISNULL(EP_E.ReEntryDate, EP_E.EntryDate)) <= @fecha_fin_mes
                        AND (
                            EP_E.CeaseDate IS NULL
                            OR CONVERT(DATE, EP_E.CeaseDate) >= @fecha_inicio_mes
                        )
                    )
              )
        );
    END;

    SELECT person, mensaje
    FROM #msg
    ORDER BY CASE WHEN person IS NULL THEN 0 ELSE 1 END, mensaje;

    DROP TABLE #msg;
    DROP TABLE #Empleados;
END
GO
