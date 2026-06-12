/*
    Validación PLAME: Neto a pagar (R01 SUNAT) vs Neto a recibir (planilla, FormulaCode = NETO).

    Usado por: POST /api/plame/validar/neto-r01

    La población de planilla es la misma que Archivo 18 (sp_pr_listado_plame18_web):
      - Todas las planillas (@payroll_all = Y por defecto)
      - Procesos: CTS, fin de mes, semana, vacaciones, liquidación, utilidades
      - Categoría empleado PDT = 1 (+ rama descanso médico legacy)
      - Excluye QUINCENA y procesos LIMABGT 10/11 en el neto
      - Respeta flag PDT por planilla/proceso cuando está configurado

    Parámetros:
      @cia         — compañía
      @period      — periodo tributario YYYYMM
      @payroll_all — Y = todas las planillas (default, igual Archivo 18)
      @payroll     — tipo de planilla (si @payroll_all = N)
      @cesados     — T/Y/N (default T, igual Archivo 18)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_neto_r01_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(6),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @cesados     CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    DECLARE @cargaid INT;

    SELECT @cargaid = C.CargaId
    FROM PR_PlameSunatCarga C (NOLOCK)
    WHERE C.Company = @cia
      AND C.Period = @period;

    IF @cargaid IS NULL
    BEGIN
        RAISERROR('No hay carga SUNAT para la compañía y periodo indicados.', 16, 1);
        RETURN;
    END

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    /* --- Misma población que Archivo 18 --- */
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
    WHERE pr_employee.company = @cia
      AND pr_mapping.company = @cia
      AND pr_employeecategory.PDT = '1'
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

    ;WITH SunatR01 AS (
        SELECT
            LTRIM(RTRIM(ISNULL(F.TipoDoc, ''))) AS tipodoc,
            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(ISNULL(F.LastName1, ''))) AS lastname1,
            LTRIM(RTRIM(ISNULL(F.LastName2, ''))) AS lastname2,
            LTRIM(RTRIM(ISNULL(F.Names, ''))) AS names,
            TRY_CAST(JSON_VALUE(F.MontosJson, '$."Neto a pagar"') AS DECIMAL(18, 2)) AS neto_sunat
        FROM PR_PlameSunatFila F (NOLOCK)
        WHERE F.CargaId = @cargaid
          AND F.Archivo = 'R01'
          AND ISNULL(LTRIM(RTRIM(F.DocumentNumber)), '') <> ''
    ),
    PlanillaNeto AS (
        SELECT
            LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
            ISNULL((
                SELECT SUM(ISNULL(EPC.ConceptValueLo, 0))
                FROM PR_EmployeePayRollConcept EPC (NOLOCK)
                    INNER JOIN PR_Concept C (NOLOCK)
                        ON EPC.Concept = C.Concept
                       AND C.Company = @cia
                    INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
                WHERE EPC.Company = @cia
                  AND EPC.Person = EM.person
                  AND LEFT(EPC.PRPeriod, 6) = @period
                  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'NETO'
                  AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
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
                  AND (
                        (SELECT COUNT(*) FROM pr_payrolltypeprocess WHERE company = @cia AND flagpdt = 'Y') = 0
                     OR EXISTS (
                            SELECT 1
                            FROM pr_payrolltypeprocess PTP
                            WHERE PTP.PayRollType = EPC.PayRollType
                              AND PTP.ProcessType = EPC.ProcessType
                              AND PTP.flagpdt = 'Y'
                        )
                    )
            ), 0) AS neto_planilla
        FROM #Empleados EM
            INNER JOIN SY_Person P (NOLOCK) ON EM.person = P.Person
        WHERE ISNULL(LTRIM(RTRIM(P.DocumentNumber)), '') <> ''
    )
    SELECT
        COALESCE(S.tipodoc, '') AS tipodoc,
        COALESCE(S.documentnumber, P.documentnumber) AS documentnumber,
        LTRIM(RTRIM(
            COALESCE(S.lastname1, '') + ' ' +
            COALESCE(S.lastname2, '') + ' ' +
            COALESCE(S.names, '')
        )) AS nombre,
        ISNULL(S.neto_sunat, 0) AS neto_sunat,
        ISNULL(P.neto_planilla, 0) AS neto_planilla,
        ROUND(ISNULL(S.neto_sunat, 0) - ISNULL(P.neto_planilla, 0), 2) AS diferencia,
        CASE
            WHEN S.documentnumber IS NULL THEN 'SOLO_PLANILLA'
            WHEN P.documentnumber IS NULL THEN 'SOLO_SUNAT'
            WHEN ABS(ISNULL(S.neto_sunat, 0) - ISNULL(P.neto_planilla, 0)) < 0.005 THEN 'OK'
            ELSE 'DIFERENCIA'
        END AS estado
    INTO #Comparacion
    FROM SunatR01 S
        FULL OUTER JOIN PlanillaNeto P
            ON S.documentnumber = P.documentnumber;

    SELECT
        COUNT(*) AS total_filas,
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) AS coinciden,
        SUM(CASE WHEN estado = 'DIFERENCIA' THEN 1 ELSE 0 END) AS con_diferencia,
        SUM(CASE WHEN estado = 'SOLO_SUNAT' THEN 1 ELSE 0 END) AS solo_sunat,
        SUM(CASE WHEN estado = 'SOLO_PLANILLA' THEN 1 ELSE 0 END) AS solo_planilla,
        ROUND(SUM(neto_sunat), 2) AS total_neto_sunat,
        ROUND(SUM(neto_planilla), 2) AS total_neto_planilla,
        ROUND(SUM(neto_sunat) - SUM(neto_planilla), 2) AS total_diferencia
    FROM #Comparacion;

    SELECT
        tipodoc,
        documentnumber,
        nombre,
        neto_sunat,
        neto_planilla,
        diferencia,
        estado
    FROM #Comparacion
    ORDER BY
        CASE estado
            WHEN 'DIFERENCIA' THEN 1
            WHEN 'SOLO_SUNAT' THEN 2
            WHEN 'SOLO_PLANILLA' THEN 3
            ELSE 4
        END,
        nombre,
        documentnumber;

    DROP TABLE #Comparacion;
    DROP TABLE #Empleados;
END
GO
