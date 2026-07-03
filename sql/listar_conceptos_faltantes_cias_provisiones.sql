/*
    Conceptos de BGT (fórmulas de provisiones) que NO existen en cada empresa destino
    con el mismo FormulaCode.

    Procesos: PROVISION CTS, PROVISION GRATIFICACION, PROVISION VACACIONES.

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @empresas_destino TABLE (cia VARCHAR(20) NOT NULL PRIMARY KEY);
INSERT INTO @empresas_destino (cia) VALUES
    ('SB01'), ('SB02'), ('SB03'), ('SB04'), ('SB05'), ('SB06');

DECLARE @procesos_origen TABLE (shortname VARCHAR(50) NOT NULL PRIMARY KEY);
INSERT INTO @procesos_origen (shortname) VALUES
    ('PROVISION_CTS'),
    ('PROVISION_VACACIONES'),
    ('PROVISION_GRATIF');

SELECT
    pt.ShortName AS proceso,
    d.cia AS company_destino,
    COUNT(DISTINCT fh.formulacode) AS conceptos_faltantes
FROM @empresas_destino d
CROSS JOIN @procesos_origen po
INNER JOIN PR_ProcessType pt
    ON pt.Company = 'BGT'
   AND pt.ShortName = po.shortname
CROSS JOIN PR_FormulaHeader fh
WHERE fh.Company = 'BGT'
  AND fh.Proccestype = pt.ProcessType
  AND fh.formulacode IS NOT NULL
  AND LTRIM(RTRIM(fh.formulacode)) <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM PR_Concept s
        WHERE s.Company = d.cia
          AND s.FormulaCode = fh.formulacode
  )
GROUP BY pt.ShortName, d.cia
ORDER BY pt.ShortName, d.cia;

SELECT
    pt.ShortName AS proceso,
    d.cia AS company_destino,
    fh.formulacode,
    c.Description AS descripcion_bgt
FROM @empresas_destino d
CROSS JOIN @procesos_origen po
INNER JOIN PR_ProcessType pt
    ON pt.Company = 'BGT'
   AND pt.ShortName = po.shortname
CROSS JOIN PR_FormulaHeader fh
LEFT JOIN PR_Concept c
    ON c.Company = 'BGT'
   AND c.FormulaCode = fh.formulacode
WHERE fh.Company = 'BGT'
  AND fh.Proccestype = pt.ProcessType
  AND fh.formulacode IS NOT NULL
  AND LTRIM(RTRIM(fh.formulacode)) <> ''
  AND NOT EXISTS (
        SELECT 1
        FROM PR_Concept s
        WHERE s.Company = d.cia
          AND s.FormulaCode = fh.formulacode
  )
GROUP BY pt.ShortName, d.cia, fh.formulacode, c.Description
ORDER BY pt.ShortName, d.cia, fh.formulacode;
