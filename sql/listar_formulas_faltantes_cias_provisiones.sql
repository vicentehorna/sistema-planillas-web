/*
    Fórmulas de PROVISION CTS, PROVISION GRATIFICACION y PROVISION VACACIONES
    de BGT que faltan en cada empresa destino (por formulacode).

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
    COUNT(DISTINCT fh.FormulaHeader) AS formulas_faltantes
FROM @empresas_destino d
CROSS JOIN @procesos_origen po
INNER JOIN PR_ProcessType pt
    ON pt.Company = 'BGT'
   AND pt.ShortName = po.shortname
INNER JOIN PR_FormulaHeader fh
    ON fh.Company = 'BGT'
   AND fh.Proccestype = pt.ProcessType
INNER JOIN PR_ProcessType ptd
    ON ptd.Company = d.cia
   AND ptd.ShortName = po.shortname
WHERE NOT EXISTS (
        SELECT 1
        FROM PR_FormulaHeader fd
        WHERE fd.Company = d.cia
          AND fd.Proccestype = ptd.ProcessType
          AND fd.formulacode = fh.formulacode
  )
GROUP BY pt.ShortName, d.cia
ORDER BY pt.ShortName, d.cia;
