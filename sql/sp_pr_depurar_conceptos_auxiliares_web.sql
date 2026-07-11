/*
    Depuración de conceptos AUXILIARES no utilizados por compañía.

    Grupos de uso:
      G1 — Fórmulas (cabecera, condición, detalle, ConceptList)
      G2 — PR_EmployeeConcept (asignación)
      G3 — PR_EmployeePayRollConcept (calculados)
      G4 — Nemónicos literales en SP de cálculo (fin de mes, liquidación,
           gratificación, provisiones CTS / grati / vacaciones)

    Resultado depurable: Maestro AUX - (G1 ∪ G2 ∪ G3 ∪ G4)

    @modo:
      RESUMEN         — conteos por grupo
      NO_USADOS       — lista final depurable (default)
      NO_USADOS_G123  — sin cruzar SP
      G1 | G2 | G3 | G4 — conceptos usados en cada grupo
      DETALLE         — maestro AUX con flags por grupo

    Ejemplo:
      EXEC sp_pr_depurar_conceptos_auxiliares_web @company = 'BGT', @modo = 'RESUMEN';
      EXEC sp_pr_depurar_conceptos_auxiliares_web @company = 'SB01', @modo = 'NO_USADOS';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_depurar_conceptos_auxiliares_web]
    @company VARCHAR(4),
    @modo    VARCHAR(20) = 'NO_USADOS'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, 'NO_USADOS'))));

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía (@company).', 16, 1);
        RETURN;
    END;

    CREATE TABLE #maestro (
        concept_id      VARCHAR(20) NOT NULL PRIMARY KEY,
        formulacode     VARCHAR(50) NULL,
        nombre_concepto VARCHAR(200) NULL,
        status          VARCHAR(10) NULL
    );

    CREATE TABLE #usado (
        concept_id VARCHAR(20) NOT NULL,
        grupo      CHAR(2) NOT NULL,
        PRIMARY KEY (concept_id, grupo)
    );

    CREATE TABLE #g4_nemonicos (
        formulacode VARCHAR(50) NOT NULL PRIMARY KEY
    );

    CREATE TABLE #tmp_nemo (
        formulacode VARCHAR(50) NOT NULL,
        origen      VARCHAR(30) NOT NULL
    );

    /* Maestro AUX */
    INSERT INTO #maestro (concept_id, formulacode, nombre_concepto, status)
    SELECT
        c.Concept,
        NULLIF(LTRIM(RTRIM(c.FormulaCode)), ''),
        NULLIF(LTRIM(RTRIM(c.Description)), ''),
        NULLIF(LTRIM(RTRIM(c.Status)), '')
    FROM PR_Concept c (NOLOCK)
        INNER JOIN PR_ConceptType ct (NOLOCK)
            ON ct.ConceptType = c.ConceptType
           AND ct.Company = c.Company
    WHERE c.Company = @company
      AND LTRIM(RTRIM(ct.ShortName)) = 'X';

    /* G1 — fórmulas */
    INSERT INTO #usado (concept_id, grupo)
    SELECT DISTINCT u.concept_id, 'G1'
    FROM (
        SELECT fh.Concept AS concept_id
        FROM PR_FormulaHeader fh (NOLOCK)
        WHERE fh.Company = @company
          AND fh.Concept IS NOT NULL
          AND LTRIM(RTRIM(fh.Concept)) <> ''

        UNION

        SELECT fh.ConceptCond
        FROM PR_FormulaHeader fh (NOLOCK)
        WHERE fh.Company = @company
          AND fh.ConceptCond IS NOT NULL
          AND LTRIM(RTRIM(fh.ConceptCond)) <> ''

        UNION

        SELECT fd.Concept
        FROM PR_FormulaHeader fh (NOLOCK)
            INNER JOIN PR_FormulaDetail fd (NOLOCK)
                ON fd.FormulaHeader = fh.FormulaHeader
        WHERE fh.Company = @company
          AND fd.Concept IS NOT NULL
          AND LTRIM(RTRIM(fd.Concept)) <> ''

        UNION

        SELECT s.concept_id
        FROM PR_FormulaHeader fh (NOLOCK)
            INNER JOIN PR_FormulaDetail fd (NOLOCK)
                ON fd.FormulaHeader = fh.FormulaHeader
        CROSS APPLY (
            SELECT LTRIM(RTRIM(
                SUBSTRING(
                    fd.ConceptList,
                    n.number,
                    CHARINDEX('|', fd.ConceptList + '|', n.number) - n.number
                )
            )) AS concept_id
            FROM master..spt_values n
            WHERE n.type = 'P'
              AND n.number BETWEEN 1 AND LEN(ISNULL(fd.ConceptList, ''))
              AND SUBSTRING('|' + fd.ConceptList, n.number, 1) = '|'
        ) s
        WHERE fh.Company = @company
          AND fd.ConceptList IS NOT NULL
          AND LTRIM(RTRIM(fd.ConceptList)) <> ''
          AND LTRIM(RTRIM(s.concept_id)) <> ''
    ) u
        INNER JOIN #maestro m ON m.concept_id = u.concept_id;

    /* G2 — asignación */
    INSERT INTO #usado (concept_id, grupo)
    SELECT DISTINCT ec.Concept, 'G2'
    FROM PR_EmployeeConcept ec (NOLOCK)
        INNER JOIN #maestro m ON m.concept_id = ec.Concept
    WHERE ec.Company = @company
      AND NOT EXISTS (
          SELECT 1 FROM #usado u
          WHERE u.concept_id = ec.Concept AND u.grupo = 'G2'
      );

    /* G3 — calculados */
    INSERT INTO #usado (concept_id, grupo)
    SELECT DISTINCT epc.Concept, 'G3'
    FROM PR_EmployeePayRollConcept epc (NOLOCK)
        INNER JOIN #maestro m ON m.concept_id = epc.Concept
    WHERE epc.Company = @company
      AND NOT EXISTS (
          SELECT 1 FROM #usado u
          WHERE u.concept_id = epc.Concept AND u.grupo = 'G3'
      );

    /* G4 — SP de cálculo (nemónicos literales) */
    DECLARE @calc_sp VARCHAR(128);
    DECLARE @calc_sps TABLE (sp_name VARCHAR(128) NOT NULL PRIMARY KEY);

    INSERT INTO @calc_sps (sp_name) VALUES
        ('sp_pr_calcular_finmes_persona'),
        ('sp_pr_calcular_liquidacion_persona'),
        ('sp_pr_calcular_gratificacion_persona'),
        ('sp_pr_calcular_provcts_persona'),
        ('sp_pr_calcular_provgrati_persona'),
        ('sp_pr_calcular_provvac_persona');

    DECLARE cur_sp CURSOR LOCAL FAST_FORWARD FOR
        SELECT sp_name FROM @calc_sps;

    OPEN cur_sp;
    FETCH NEXT FROM cur_sp INTO @calc_sp;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DELETE FROM #tmp_nemo;

        INSERT INTO #tmp_nemo (formulacode, origen)
        EXEC dbo.sp_pr_extraer_nemonicos_literal_sp_web @procedure_name = @calc_sp;

        INSERT INTO #g4_nemonicos (formulacode)
        SELECT DISTINCT t.formulacode
        FROM #tmp_nemo t
        WHERE NOT EXISTS (
            SELECT 1 FROM #g4_nemonicos g WHERE g.formulacode = t.formulacode
        );

        FETCH NEXT FROM cur_sp INTO @calc_sp;
    END;

    CLOSE cur_sp;
    DEALLOCATE cur_sp;

    INSERT INTO #usado (concept_id, grupo)
    SELECT m.concept_id, 'G4'
    FROM #maestro m
        INNER JOIN #g4_nemonicos g
            ON g.formulacode = UPPER(LTRIM(RTRIM(ISNULL(m.formulacode, ''))))
    WHERE LTRIM(RTRIM(ISNULL(m.formulacode, ''))) <> ''
      AND NOT EXISTS (
          SELECT 1 FROM #usado u
          WHERE u.concept_id = m.concept_id AND u.grupo = 'G4'
      );

    IF @modo = 'RESUMEN'
    BEGIN
        SELECT
            @company AS company,
            (SELECT COUNT(*) FROM #maestro) AS maestro_aux,
            (SELECT COUNT(DISTINCT concept_id) FROM #usado WHERE grupo = 'G1') AS g1_formulas,
            (SELECT COUNT(DISTINCT concept_id) FROM #usado WHERE grupo = 'G2') AS g2_asignacion,
            (SELECT COUNT(DISTINCT concept_id) FROM #usado WHERE grupo = 'G3') AS g3_calculados,
            (SELECT COUNT(DISTINCT concept_id) FROM #usado WHERE grupo = 'G4') AS g4_sp_calculo,
            (SELECT COUNT(DISTINCT concept_id) FROM #usado WHERE grupo IN ('G1', 'G2', 'G3')) AS usados_g123,
            (SELECT COUNT(DISTINCT concept_id) FROM #usado) AS usados_g1234,
            (SELECT COUNT(*)
             FROM #maestro m
             WHERE NOT EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id AND u.grupo IN ('G1', 'G2', 'G3'))
            ) AS no_usados_g123,
            (SELECT COUNT(*)
             FROM #maestro m
             WHERE NOT EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id)
            ) AS no_usados_definitivos;
        RETURN;
    END;

    IF @modo IN ('G1', 'G2', 'G3', 'G4')
    BEGIN
        SELECT
            @company AS company,
            m.formulacode,
            m.nombre_concepto,
            m.concept_id,
            m.status
        FROM #usado u
            INNER JOIN #maestro m ON m.concept_id = u.concept_id
        WHERE u.grupo = @modo
        ORDER BY m.formulacode, m.nombre_concepto;
        RETURN;
    END;

    IF @modo = 'DETALLE'
    BEGIN
        SELECT
            @company AS company,
            m.formulacode,
            m.nombre_concepto,
            m.concept_id,
            m.status,
            CASE WHEN EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id AND u.grupo = 'G1') THEN 'S' ELSE 'N' END AS en_g1,
            CASE WHEN EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id AND u.grupo = 'G2') THEN 'S' ELSE 'N' END AS en_g2,
            CASE WHEN EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id AND u.grupo = 'G3') THEN 'S' ELSE 'N' END AS en_g3,
            CASE WHEN EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id AND u.grupo = 'G4') THEN 'S' ELSE 'N' END AS en_g4,
            CASE WHEN EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id) THEN 'N' ELSE 'S' END AS depurable
        FROM #maestro m
        ORDER BY depurable DESC, m.formulacode, m.nombre_concepto;
        RETURN;
    END;

    IF @modo = 'NO_USADOS_G123'
    BEGIN
        SELECT
            @company AS company,
            m.formulacode,
            m.nombre_concepto,
            m.concept_id,
            m.status
        FROM #maestro m
        WHERE NOT EXISTS (
            SELECT 1 FROM #usado u
            WHERE u.concept_id = m.concept_id
              AND u.grupo IN ('G1', 'G2', 'G3')
        )
        ORDER BY m.formulacode, m.nombre_concepto;
        RETURN;
    END;

    /* NO_USADOS (default) */
    SELECT
        @company AS company,
        m.formulacode,
        m.nombre_concepto,
        m.concept_id,
        m.status
    FROM #maestro m
    WHERE NOT EXISTS (SELECT 1 FROM #usado u WHERE u.concept_id = m.concept_id)
    ORDER BY m.formulacode, m.nombre_concepto;
END
GO
