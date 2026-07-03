/*
    Fórmulas LIQUIDACIÓN de BGT que faltan en cada empresa destino (por formulacode).

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @empresas_destino TABLE (cia VARCHAR(20) NOT NULL PRIMARY KEY);
INSERT INTO @empresas_destino (cia) VALUES
    ('SB01'), ('SB02'), ('SB03'), ('SB04'), ('SB05'), ('SB06');

SELECT
    d.cia AS company_destino,
    COUNT(DISTINCT fh.formulacode) AS formulas_faltantes
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
        FROM PR_FormulaHeader fd
        INNER JOIN PR_ProcessType ptd
            ON fd.Proccestype = ptd.ProcessType
        WHERE fd.Company = d.cia
          AND ptd.ShortName = 'LIQUIDACION'
          AND fd.formulacode = fh.formulacode
  )
GROUP BY d.cia
ORDER BY d.cia;
