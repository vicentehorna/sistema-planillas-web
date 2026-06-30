/*
    Conceptos de BGT (fórmulas LIQUIDACIÓN) que NO existen en SB03
    con el mismo FormulaCode — bloquean sp_pr_replicar_formula_cia.

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

SELECT
    c.Concept              AS concept_bgt,
    c.FormulaCode          AS formulacode,
    c.Description          AS descripcion_bgt,
    fh.FormulaHeader       AS formulaheader_bgt,
    fh.Description         AS formula_descripcion,
    pt.ShortName           AS proceso,
    pr.ShortName           AS planilla
FROM PR_FormulaHeader fh
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
INNER JOIN PR_PayRollType pr
    ON fh.Payrolltype = pr.PayRollType
INNER JOIN PR_Concept c
    ON c.Company = fh.Company
   AND c.FormulaCode = fh.formulacode
WHERE fh.Company = 'BGT'
  AND pt.ShortName = 'LIQUIDACION'
  AND NOT EXISTS (
        SELECT 1
        FROM PR_Concept s
        WHERE s.Company = 'SB03'
          AND s.FormulaCode = fh.formulacode
  )
ORDER BY
    c.FormulaCode,
    fh.FormulaHeader;

-- Resumen
SELECT COUNT(*) AS total_conceptos_faltantes
FROM (
    SELECT DISTINCT fh.formulacode
    FROM PR_FormulaHeader fh
    INNER JOIN PR_ProcessType pt
        ON fh.Proccestype = pt.ProcessType
    WHERE fh.Company = 'BGT'
      AND pt.ShortName = 'LIQUIDACION'
      AND NOT EXISTS (
            SELECT 1
            FROM PR_Concept s
            WHERE s.Company = 'SB03'
              AND s.FormulaCode = fh.formulacode
      )
) x;
