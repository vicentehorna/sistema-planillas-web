/*
    Consultas de referencia — depuración conceptos AUXILIARES por compañía.

    Recomendado: usar el SP sp_pr_depurar_conceptos_auxiliares_web (modos RESUMEN,
    NO_USADOS, G1, G2, G3, G4, DETALLE).

    Este archivo documenta la lógica por grupo para ejecutar manualmente en SSMS.
    Cambie @company según la empresa destino (BGT, SB01, SB02, ...).
*/
DECLARE @company VARCHAR(4) = 'BGT';

/* =============================================================================
   MAESTRO — conceptos tipo Auxiliares (ShortName = 'X')
   ============================================================================= */
SELECT
    c.Company,
    c.Concept AS concept_id,
    LTRIM(RTRIM(c.FormulaCode)) AS formulacode,
    LTRIM(RTRIM(c.Description)) AS nombre_concepto,
    LTRIM(RTRIM(c.Status)) AS status
FROM PR_Concept c
    INNER JOIN PR_ConceptType ct
        ON ct.ConceptType = c.ConceptType
       AND ct.Company = c.Company
WHERE c.Company = @company
  AND LTRIM(RTRIM(ct.ShortName)) = 'X'
ORDER BY c.FormulaCode, c.Description;

GO

DECLARE @company VARCHAR(4) = 'BGT';

/* =============================================================================
   GRUPO 1 — AUX usados en fórmulas (cabecera, condición, detalle, ConceptList)
   ============================================================================= */
SELECT DISTINCT
    c.Company,
    c.Concept AS concept_id,
    LTRIM(RTRIM(c.FormulaCode)) AS formulacode,
    LTRIM(RTRIM(c.Description)) AS nombre_concepto
FROM (
    SELECT fh.Company, fh.Concept AS concept_id
    FROM PR_FormulaHeader fh
    WHERE fh.Company = @company
      AND fh.Concept IS NOT NULL AND LTRIM(RTRIM(fh.Concept)) <> ''

    UNION

    SELECT fh.Company, fh.ConceptCond
    FROM PR_FormulaHeader fh
    WHERE fh.Company = @company
      AND fh.ConceptCond IS NOT NULL AND LTRIM(RTRIM(fh.ConceptCond)) <> ''

    UNION

    SELECT fh.Company, fd.Concept
    FROM PR_FormulaHeader fh
    INNER JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
    WHERE fh.Company = @company
      AND fd.Concept IS NOT NULL AND LTRIM(RTRIM(fd.Concept)) <> ''

    UNION

    SELECT fh.Company, s.concept_id
    FROM PR_FormulaHeader fh
    INNER JOIN PR_FormulaDetail fd ON fd.FormulaHeader = fh.FormulaHeader
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
    INNER JOIN PR_Concept c
        ON c.Concept = u.concept_id AND c.Company = u.Company
    INNER JOIN PR_ConceptType ct
        ON ct.ConceptType = c.ConceptType AND ct.Company = c.Company
WHERE LTRIM(RTRIM(ct.ShortName)) = 'X'
ORDER BY formulacode;

GO

DECLARE @company VARCHAR(4) = 'BGT';

/* =============================================================================
   GRUPO 2 — AUX en asignación (PR_EmployeeConcept)
   ============================================================================= */
SELECT DISTINCT
    c.Company,
    c.Concept AS concept_id,
    LTRIM(RTRIM(c.FormulaCode)) AS formulacode,
    LTRIM(RTRIM(c.Description)) AS nombre_concepto
FROM PR_EmployeeConcept ec
    INNER JOIN PR_Concept c
        ON c.Concept = ec.Concept AND c.Company = ec.Company
    INNER JOIN PR_ConceptType ct
        ON ct.ConceptType = c.ConceptType AND ct.Company = c.Company
WHERE ec.Company = @company
  AND LTRIM(RTRIM(ct.ShortName)) = 'X'
ORDER BY formulacode;

GO

DECLARE @company VARCHAR(4) = 'BGT';

/* =============================================================================
   GRUPO 3 — AUX calculados (PR_EmployeePayRollConcept)
   ============================================================================= */
SELECT DISTINCT
    c.Company,
    c.Concept AS concept_id,
    LTRIM(RTRIM(c.FormulaCode)) AS formulacode,
    LTRIM(RTRIM(c.Description)) AS nombre_concepto
FROM PR_EmployeePayRollConcept epc
    INNER JOIN PR_Concept c
        ON c.Concept = epc.Concept AND c.Company = epc.Company
    INNER JOIN PR_ConceptType ct
        ON ct.ConceptType = c.ConceptType AND ct.Company = c.Company
WHERE epc.Company = @company
  AND LTRIM(RTRIM(ct.ShortName)) = 'X'
ORDER BY formulacode;

GO

/* =============================================================================
   GRUPO 4 — Nemónicos literales en SP de cálculo
   (usar sp_pr_extraer_nemonicos_literal_sp_web por cada SP o el SP principal)
   ============================================================================= */
EXEC dbo.sp_pr_extraer_nemonicos_literal_sp_web
    @procedure_name = 'sp_pr_calcular_finmes_persona';

EXEC dbo.sp_pr_extraer_nemonicos_literal_sp_web
    @procedure_name = 'sp_pr_calcular_liquidacion_persona';

EXEC dbo.sp_pr_extraer_nemonicos_literal_sp_web
    @procedure_name = 'sp_pr_calcular_gratificacion_persona';

EXEC dbo.sp_pr_extraer_nemonicos_literal_sp_web
    @procedure_name = 'sp_pr_calcular_provcts_persona';

EXEC dbo.sp_pr_extraer_nemonicos_literal_sp_web
    @procedure_name = 'sp_pr_calcular_provgrati_persona';

EXEC dbo.sp_pr_extraer_nemonicos_literal_sp_web
    @procedure_name = 'sp_pr_calcular_provvac_persona';

GO

DECLARE @company VARCHAR(4) = 'BGT';

/* =============================================================================
   SP PRINCIPAL — resumen y listas (recomendado)
   ============================================================================= */
EXEC dbo.sp_pr_depurar_conceptos_auxiliares_web
    @company = @company,
    @modo = 'RESUMEN';

EXEC dbo.sp_pr_depurar_conceptos_auxiliares_web
    @company = @company,
    @modo = 'NO_USADOS';

EXEC dbo.sp_pr_depurar_conceptos_auxiliares_web
    @company = @company,
    @modo = 'DETALLE';

GO
