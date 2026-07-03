/*
    Conceptos de BGT (fórmulas LIQUIDACIÓN) que NO existen en cada empresa destino
    con el mismo FormulaCode.

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @empresas_destino TABLE (cia VARCHAR(20) NOT NULL PRIMARY KEY);
INSERT INTO @empresas_destino (cia) VALUES
    ('SB01'), ('SB02'), ('SB03'), ('SB04'), ('SB05'), ('SB06');

SELECT
    d.cia AS company_destino,
    COUNT(DISTINCT fh.formulacode) AS conceptos_faltantes
FROM @empresas_destino d
CROSS JOIN PR_FormulaHeader fh
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
WHERE fh.Company = 'BGT'
  AND pt.ShortName = 'LIQUIDACION'
  AND fh.formulacode IS NOT NULL
  AND LTRIM(RTRIM(fh.formulacode)) <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM PR_Concept s
        WHERE s.Company = d.cia
          AND s.FormulaCode = fh.formulacode
  )
GROUP BY d.cia
ORDER BY d.cia;

SELECT
    d.cia AS company_destino,
    fh.formulacode,
    c.Description AS descripcion_bgt
FROM @empresas_destino d
CROSS JOIN PR_FormulaHeader fh
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
LEFT JOIN PR_Concept c
    ON c.Company = 'BGT'
   AND c.FormulaCode = fh.formulacode
WHERE fh.Company = 'BGT'
  AND pt.ShortName = 'LIQUIDACION'
  AND fh.formulacode IS NOT NULL
  AND LTRIM(RTRIM(fh.formulacode)) <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM PR_Concept s
        WHERE s.Company = d.cia
          AND s.FormulaCode = fh.formulacode
  )
GROUP BY d.cia, fh.formulacode, c.Description
ORDER BY d.cia, fh.formulacode;
