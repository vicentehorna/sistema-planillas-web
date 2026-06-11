/*
    Resumen Declaración AFP — cuadros de verificación post-generación AFPnet.

    Usado por: POST /api/declaracion-afp/generar-xlsx

    Resultset 1 — Montos TOTAL_REM_AFP por proceso (FIN_DE_MES, LIQUIDACION, SEMANAL).
              Jubilados (FLAG_JUBILADO) no suman: en AFPnet su remuneración asegurable es 0.
    Resultset 2 — Conteo trabajadores en planilla (nuevos / cesados / antiguos).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_resumen_declaracion_afp_web]
    @cia              VARCHAR(10),
    @period           VARCHAR(20),
    @payroll_all      CHAR(1)     = 'Y',
    @payroll          VARCHAR(20) = NULL,
    @afp_all          CHAR(1)     = 'Y',
    @afp              VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @afp_all = UPPER(LTRIM(RTRIM(ISNULL(@afp_all, 'Y'))));
    SET @afp = LTRIM(RTRIM(ISNULL(@afp, '')));

    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @afp_all NOT IN ('Y', 'N') SET @afp_all = 'Y';
    IF @payroll_all = 'Y' SET @payroll = '';
    IF @afp_all = 'Y' SET @afp = '';

    /* Solo trabajadores con régimen AFP (legacy: ISNULL(PR_Employee.AFP,'') <> ''). */

    /* --- Resultset 1: montos por proceso --- */
    SELECT
        P.proceso,
        CAST(ISNULL(M.monto, 0) AS DECIMAL(19, 2)) AS monto
    FROM (
        SELECT 'FIN_DE_MES' AS proceso, 1 AS orden
        UNION ALL SELECT 'LIQUIDACION', 2
        UNION ALL SELECT 'SEMANAL', 3
    ) P
    LEFT JOIN (
        SELECT
            LTRIM(RTRIM(PT.ShortName)) AS proceso,
            SUM(CAST(ISNULL(EPC.ConceptValueLo, 0) AS DECIMAL(19, 2))) AS monto
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK)
                ON EPC.Concept = C.Concept
               AND EPC.Company = C.Company
            INNER JOIN PR_ProcessType PT (NOLOCK)
                ON EPC.ProcessType = PT.ProcessType
               AND PT.Company = @cia
            INNER JOIN PR_Employee E (NOLOCK)
                ON E.person = EPC.Person
               AND E.company = EPC.Company
        WHERE EPC.Company = @cia
          AND LEFT(EPC.PRPeriod, 6) = @period
          AND C.FormulaCode = 'TOTAL_REM_AFP'
          AND LTRIM(RTRIM(PT.ShortName)) IN ('FIN_DE_MES', 'LIQUIDACION', 'SEMANAL')
          AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
          AND ISNULL(LTRIM(RTRIM(E.AFP)), '') <> ''
          AND (@afp_all = 'Y' OR LTRIM(RTRIM(E.AFP)) = @afp)
          /* Jubilados: no incluir su TOTAL_REM_AFP (AFPnet reporta remuneración 0). */
          AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept EC (NOLOCK)
                    INNER JOIN PR_Concept Cj (NOLOCK)
                        ON EC.Concept = Cj.Concept
                       AND Cj.Company = @cia
                WHERE EC.Company = @cia
                  AND EC.Person = EPC.Person
                  AND Cj.FormulaCode = 'FLAG_JUBILADO'
                  AND EC.FlagFrecuencyType IN ('P', 'T')
                  AND (
                        EC.FlagFrecuencyType = 'P'
                        OR (EC.FlagFrecuencyType = 'T' AND LEFT(EC.PRPeriodStart, 6) = @period)
                      )
                  AND (@payroll_all = 'Y' OR EC.PayRollType = @payroll)
          )
        GROUP BY LTRIM(RTRIM(PT.ShortName))
    ) M ON M.proceso = P.proceso
    ORDER BY P.orden;

    /* --- Población planilla: trabajadores con AFP (TOTAL_REM_AFP + jubilados) --- */
    CREATE TABLE #TrabajadoresPlanilla (
        person VARCHAR(20) NOT NULL PRIMARY KEY,
        es_jubilado CHAR(1) NOT NULL DEFAULT 'N'
    );

    INSERT INTO #TrabajadoresPlanilla (person, es_jubilado)
    SELECT DISTINCT
        LTRIM(RTRIM(EPC.Person)),
        'N'
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON EPC.Concept = C.Concept
           AND EPC.Company = C.Company
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.person = EPC.Person
           AND E.company = EPC.Company
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND C.FormulaCode = 'TOTAL_REM_AFP'
      AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
      AND ISNULL(LTRIM(RTRIM(E.AFP)), '') <> ''
      AND (@afp_all = 'Y' OR LTRIM(RTRIM(E.AFP)) = @afp);

    INSERT INTO #TrabajadoresPlanilla (person, es_jubilado)
    SELECT DISTINCT
        LTRIM(RTRIM(EC.Person)),
        'S'
    FROM PR_EmployeeConcept EC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON EC.Concept = C.Concept
           AND C.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.person = EC.Person
           AND E.company = EC.Company
    WHERE EC.Company = @cia
      AND C.FormulaCode = 'FLAG_JUBILADO'
      AND EC.FlagFrecuencyType IN ('P', 'T')
      AND (
            EC.FlagFrecuencyType = 'P'
            OR (EC.FlagFrecuencyType = 'T' AND LEFT(EC.PRPeriodStart, 6) = @period)
          )
      AND (@payroll_all = 'Y' OR EC.PayRollType = @payroll)
      AND ISNULL(LTRIM(RTRIM(E.AFP)), '') <> ''
      AND (@afp_all = 'Y' OR LTRIM(RTRIM(E.AFP)) = @afp)
      AND NOT EXISTS (
            SELECT 1
            FROM #TrabajadoresPlanilla T
            WHERE T.person = LTRIM(RTRIM(EC.Person))
      );

    /* --- Resultset 2: conteo planilla ---
       Nuevos/cesados por bandera en el periodo (pueden coincidir en un mismo trabajador).
       total_planilla = trabajadores únicos en la población. */
    SELECT
        SUM(CASE WHEN inicio_en_periodo = 1 THEN 1 ELSE 0 END) AS nuevos,
        SUM(CASE WHEN cese_en_periodo = 1 THEN 1 ELSE 0 END) AS cesados,
        SUM(CASE WHEN inicio_en_periodo = 0 AND cese_en_periodo = 0 THEN 1 ELSE 0 END) AS antiguos,
        COUNT(*) AS total_planilla
    FROM (
        SELECT
            T.person,
            CASE
                WHEN T.es_jubilado = 'S' THEN 0
                WHEN E.reentrydate IS NOT NULL
                 AND LEFT(CONVERT(VARCHAR(8), E.reentrydate, 112), 6) = @period THEN 1
                WHEN E.reentrydate IS NULL
                 AND E.entrydate IS NOT NULL
                 AND LEFT(CONVERT(VARCHAR(8), E.entrydate, 112), 6) = @period THEN 1
                ELSE 0
            END AS inicio_en_periodo,
            CASE
                WHEN E.ceasedate IS NOT NULL
                 AND LEFT(CONVERT(VARCHAR(8), E.ceasedate, 112), 6) = @period THEN 1
                ELSE 0
            END AS cese_en_periodo
        FROM #TrabajadoresPlanilla T
            INNER JOIN PR_Employee E (NOLOCK)
                ON E.person = T.person
               AND E.company = @cia
    ) X;

    DROP TABLE #TrabajadoresPlanilla;
END
GO
