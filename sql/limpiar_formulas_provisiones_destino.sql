/*
    Elimina fórmulas de provisiones en empresas destino (SB01–SB06)
    antes de replicar desde BGT.

    Procesos:
      - PROVISION CTS          (PROVISION_CTS)
      - PROVISION GRATIFICACION (PROVISION_GRATIF)
      - PROVISION VACACIONES   (PROVISION_VACACIONES)

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @empresas_destino TABLE (cia VARCHAR(20) NOT NULL PRIMARY KEY);
INSERT INTO @empresas_destino (cia) VALUES
    ('SB01'), ('SB02'), ('SB03'), ('SB04'), ('SB05'), ('SB06');

DECLARE @procesos TABLE (shortname VARCHAR(50) NOT NULL PRIMARY KEY);
INSERT INTO @procesos (shortname) VALUES
    ('PROVISION_CTS'),
    ('PROVISION_VACACIONES'),
    ('PROVISION_GRATIF');

DECLARE @detalle_eliminado INT = 0;
DECLARE @header_eliminado  INT = 0;

SELECT
    d.cia AS company_destino,
    po.shortname AS proceso,
    COUNT(DISTINCT fh.FormulaHeader) AS formulas_antes
FROM @empresas_destino d
CROSS JOIN @procesos po
INNER JOIN PR_ProcessType pt
    ON pt.Company = d.cia
   AND pt.ShortName = po.shortname
LEFT JOIN PR_FormulaHeader fh
    ON fh.Company = d.cia
   AND fh.Proccestype = pt.ProcessType
GROUP BY d.cia, po.shortname
ORDER BY po.shortname, d.cia;

DELETE fd
FROM PR_FormulaDetail fd
INNER JOIN PR_FormulaHeader fh
    ON fd.FormulaHeader = fh.FormulaHeader
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
   AND fh.Company = pt.Company
INNER JOIN @empresas_destino d
    ON d.cia = fh.Company
INNER JOIN @procesos po
    ON po.shortname = pt.ShortName;

SET @detalle_eliminado = @@ROWCOUNT;

DELETE fh
FROM PR_FormulaHeader fh
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
   AND fh.Company = pt.Company
INNER JOIN @empresas_destino d
    ON d.cia = fh.Company
INNER JOIN @procesos po
    ON po.shortname = pt.ShortName;

SET @header_eliminado = @@ROWCOUNT;

SELECT
    @detalle_eliminado AS detalle_eliminado,
    @header_eliminado  AS header_eliminado;

SELECT
    d.cia AS company_destino,
    po.shortname AS proceso,
    COUNT(DISTINCT fh.FormulaHeader) AS formulas_despues
FROM @empresas_destino d
CROSS JOIN @procesos po
INNER JOIN PR_ProcessType pt
    ON pt.Company = d.cia
   AND pt.ShortName = po.shortname
LEFT JOIN PR_FormulaHeader fh
    ON fh.Company = d.cia
   AND fh.Proccestype = pt.ProcessType
GROUP BY d.cia, po.shortname
ORDER BY po.shortname, d.cia;
