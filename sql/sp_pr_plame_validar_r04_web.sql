/*
    Validación PLAME R04: tributos del trabajador (AFP aporte/comisión/seguro, ONP, 5ta) vs planilla.

    Usado por: POST /api/plame/validar/r04

    Mapeo R04 SUNAT (MontosJson) → FormulaCode planilla:
      Aporte AFP     → AFP_APORTE_PORC_8      (S.P.P. Aporte Obligatorio)
      Comisión AFP   → AFP_COMISION_VARIABL   (S.P.P. Comisión)
      Seguro AFP     → AFP_SEGUROS            (S.P.P. Seguro)
      ONP            → ONP                    (S.N.P. D.Ley 19990 + Asegura tu pensión)
      5ta categoría  → RET_5TA_CATEGORIA      (Imp. Renta 5ta.categ.)

    Población planilla: misma que Archivo 18 / validación R01.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_r04_web]
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

    CREATE TABLE #ConceptosMap (
        concepto        VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY,
        concepto_nombre NVARCHAR(80) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        formula_code    VARCHAR(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    );

    INSERT INTO #ConceptosMap (concepto, concepto_nombre, formula_code) VALUES
        ('APORTE',   'Aporte AFP',           'AFP_APORTE_PORC_8'),
        ('COMISION', 'Comisión AFP',         'AFP_COMISION_VARIABL'),
        ('SEGURO',   'Seguro AFP',           'AFP_SEGUROS'),
        ('ONP',      'ONP',                  'ONP'),
        ('5TA',      'Renta 5ta categoría',  'RET_5TA_CATEGORIA');

    /* --- Población planilla (Archivo 18) --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT pr_employee.person
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
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

    /* --- Con tributos en planilla aunque no tenga I/A Archivo 18 --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT EPC.Person
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept AND C.Company = @cia
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK) ON EPC.Person = E.Person AND EPC.Company = E.Company
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) IN (
            'AFP_APORTE_PORC_8',
            'AFP_COMISION_VARIABL',
            'AFP_SEGUROS',
            'ONP',
            'RET_5TA_CATEGORIA'
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
      AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EPC.Person);

    ;WITH SunatR04Base AS (
        SELECT
            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) AS documentnumber,
            CASE
                WHEN LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) = '' THEN ''
                WHEN LTRIM(RTRIM(F.DocumentNumber)) NOT LIKE '%[^0-9]%'
                    THEN CAST(TRY_CAST(LTRIM(RTRIM(F.DocumentNumber)) AS BIGINT) AS VARCHAR(20))
                ELSE UPPER(LTRIM(RTRIM(F.DocumentNumber)))
            END AS doc_key,
            LTRIM(RTRIM(
                ISNULL(F.LastName1, '') + ' ' +
                ISNULL(F.LastName2, '') + ' ' +
                ISNULL(F.Names, '')
            )) AS nombre,
            F.MontosJson
        FROM PR_PlameSunatFila F (NOLOCK)
        WHERE F.CargaId = @cargaid
          AND F.Archivo = 'R04'
          AND ISNULL(LTRIM(RTRIM(F.DocumentNumber)), '') <> ''
    ),
    SunatMontos AS (
        SELECT documentnumber, doc_key, nombre, 'APORTE' AS concepto, 'Aporte AFP' AS concepto_nombre,
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.P.P. Aporte Obligatorio"') AS DECIMAL(18, 2)), 0) AS monto_sunat
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, doc_key, nombre, 'COMISION', 'Comisión AFP',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.P.P. Comisión"') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, doc_key, nombre, 'SEGURO', 'Seguro AFP',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.P.P. Seguro"') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, doc_key, nombre, 'ONP', 'ONP',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.N.P. D.Ley 19990 (ONP)"') AS DECIMAL(18, 2)), 0)
          + ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.N.P. Asegura tu pensión (ONP)"') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, doc_key, nombre, '5TA', 'Renta 5ta categoría',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."Imp. Renta 5ta.categ."') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
    ),
    PlanillaMontos AS (
        SELECT
            LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
            CASE
                WHEN LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) = '' THEN ''
                WHEN LTRIM(RTRIM(P.DocumentNumber)) NOT LIKE '%[^0-9]%'
                    THEN CAST(TRY_CAST(LTRIM(RTRIM(P.DocumentNumber)) AS BIGINT) AS VARCHAR(20))
                ELSE UPPER(LTRIM(RTRIM(P.DocumentNumber)))
            END AS doc_key,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS nombre,
            CM.concepto,
            CM.concepto_nombre,
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
                  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = UPPER(CM.formula_code)
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
            ), 0) AS monto_planilla
        FROM #Empleados EM
            INNER JOIN SY_Person P (NOLOCK) ON EM.person = P.Person
            CROSS JOIN #ConceptosMap CM
        WHERE ISNULL(LTRIM(RTRIM(P.DocumentNumber)), '') <> ''
    )
    SELECT
        COALESCE(S.concepto, P.concepto) AS concepto,
        COALESCE(S.concepto_nombre, P.concepto_nombre) AS concepto_nombre,
        COALESCE(S.documentnumber, P.documentnumber) AS documentnumber,
        LTRIM(RTRIM(COALESCE(NULLIF(S.nombre, ''), P.nombre))) AS nombre,
        ISNULL(S.monto_sunat, 0) AS monto_sunat,
        ISNULL(P.monto_planilla, 0) AS monto_planilla,
        ROUND(ISNULL(S.monto_sunat, 0) - ISNULL(P.monto_planilla, 0), 2) AS diferencia,
        CASE
            WHEN S.doc_key IS NULL THEN 'SOLO_PLANILLA'
            WHEN P.doc_key IS NULL THEN 'SOLO_SUNAT'
            WHEN ABS(ISNULL(S.monto_sunat, 0) - ISNULL(P.monto_planilla, 0)) < 0.005 THEN 'OK'
            ELSE 'DIFERENCIA'
        END AS estado
    INTO #Comparacion
    FROM SunatMontos S
        FULL OUTER JOIN PlanillaMontos P
            ON S.doc_key = P.doc_key
           AND S.doc_key <> ''
           AND S.concepto = P.concepto;

    /* Resumen por concepto */
    SELECT
        concepto,
        concepto_nombre,
        COUNT(*) AS total_filas,
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) AS coinciden,
        SUM(CASE WHEN estado = 'DIFERENCIA' THEN 1 ELSE 0 END) AS con_diferencia,
        SUM(CASE WHEN estado = 'SOLO_SUNAT' THEN 1 ELSE 0 END) AS solo_sunat,
        SUM(CASE WHEN estado = 'SOLO_PLANILLA' THEN 1 ELSE 0 END) AS solo_planilla,
        ROUND(SUM(monto_sunat), 2) AS total_sunat,
        ROUND(SUM(monto_planilla), 2) AS total_planilla,
        ROUND(SUM(monto_sunat) - SUM(monto_planilla), 2) AS total_diferencia
    FROM #Comparacion
    GROUP BY concepto, concepto_nombre
    ORDER BY
        CASE concepto
            WHEN 'APORTE' THEN 1
            WHEN 'COMISION' THEN 2
            WHEN 'SEGURO' THEN 3
            WHEN 'ONP' THEN 4
            WHEN '5TA' THEN 5
            ELSE 9
        END;

    /* Detalle */
    SELECT
        concepto,
        concepto_nombre,
        documentnumber,
        nombre,
        monto_sunat,
        monto_planilla,
        diferencia,
        estado
    FROM #Comparacion
    ORDER BY
        CASE concepto
            WHEN 'APORTE' THEN 1
            WHEN 'COMISION' THEN 2
            WHEN 'SEGURO' THEN 3
            WHEN 'ONP' THEN 4
            WHEN '5TA' THEN 5
            ELSE 9
        END,
        CASE estado
            WHEN 'DIFERENCIA' THEN 1
            WHEN 'SOLO_SUNAT' THEN 2
            WHEN 'SOLO_PLANILLA' THEN 3
            ELSE 4
        END,
        nombre,
        documentnumber;

    DROP TABLE #Comparacion;
    DROP TABLE #ConceptosMap;
    DROP TABLE #Empleados;
END
GO
