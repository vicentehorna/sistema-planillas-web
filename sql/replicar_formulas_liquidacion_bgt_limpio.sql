/*
    Replica fórmulas LIQUIDACIÓN de BGT → SB01–SB06 (limpieza + replicación).

    1) Elimina fórmulas LIQUIDACIÓN existentes en destino.
    2) Replica todas las fórmulas de BGT con sp_pr_replicar_formula_cia (versión corregida).

    Requisito previo: conceptos replicados en destino (mismo FormulaCode).

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @cia_origen VARCHAR(20) = 'BGT';

DECLARE @empresas_destino TABLE (cia VARCHAR(20) NOT NULL PRIMARY KEY);
INSERT INTO @empresas_destino (cia) VALUES
    ('SB01'), ('SB02'), ('SB03'), ('SB04'), ('SB05'), ('SB06');

/* --- Paso 1: limpiar destino --- */
DELETE fd
FROM PR_FormulaDetail fd
INNER JOIN PR_FormulaHeader fh
    ON fd.FormulaHeader = fh.FormulaHeader
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
   AND fh.Company = pt.Company
INNER JOIN @empresas_destino d
    ON d.cia = fh.Company
WHERE pt.ShortName = 'LIQUIDACION';

DELETE fh
FROM PR_FormulaHeader fh
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
   AND fh.Company = pt.Company
INNER JOIN @empresas_destino d
    ON d.cia = fh.Company
WHERE pt.ShortName = 'LIQUIDACION';

/* --- Paso 2: replicar desde BGT --- */
DECLARE @formulaheader VARCHAR(20);
DECLARE @formulacode   VARCHAR(50);
DECLARE @total         INT = 0;
DECLARE @replicados    INT = 0;
DECLARE @errores       INT = 0;

IF OBJECT_ID('tempdb..#ResultadoReplicaFormulas') IS NOT NULL
    DROP TABLE #ResultadoReplicaFormulas;

CREATE TABLE #ResultadoReplicaFormulas (
    formulaheader_bgt VARCHAR(20)  NOT NULL,
    formulacode       VARCHAR(50)  NULL,
    estado            VARCHAR(20)  NOT NULL,
    mensaje           VARCHAR(500) NULL
);

DECLARE cur_formulas CURSOR LOCAL FAST_FORWARD FOR
    SELECT fh.FormulaHeader, fh.formulacode
    FROM PR_FormulaHeader fh
    INNER JOIN PR_ProcessType pt
        ON fh.Proccestype = pt.ProcessType
       AND fh.Company = pt.Company
    WHERE fh.Company = @cia_origen
      AND pt.ShortName = 'LIQUIDACION'
    ORDER BY fh.orden, fh.FormulaHeader;

OPEN cur_formulas;
FETCH NEXT FROM cur_formulas INTO @formulaheader, @formulacode;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @total += 1;

    BEGIN TRY
        EXEC dbo.sp_pr_replicar_formula_cia
            @cia = @cia_origen,
            @formulacode = @formulacode,
            @formulaheader = @formulaheader;

        INSERT INTO #ResultadoReplicaFormulas (formulaheader_bgt, formulacode, estado, mensaje)
        VALUES (@formulaheader, @formulacode, 'REPLICADO', 'OK');

        SET @replicados += 1;
    END TRY
    BEGIN CATCH
        INSERT INTO #ResultadoReplicaFormulas (formulaheader_bgt, formulacode, estado, mensaje)
        VALUES (@formulaheader, @formulacode, 'ERROR', ERROR_MESSAGE());

        SET @errores += 1;
    END CATCH;

    FETCH NEXT FROM cur_formulas INTO @formulaheader, @formulacode;
END;

CLOSE cur_formulas;
DEALLOCATE cur_formulas;

SELECT
    @total      AS total_procesados,
    @replicados  AS replicados,
    @errores     AS errores;

SELECT
    d.cia AS company_destino,
    bgt.cnt AS formulas_bgt,
    ISNULL(dest.cnt, 0) AS formulas_destino,
    bgt.cnt - ISNULL(dest.cnt, 0) AS faltantes
FROM @empresas_destino d
CROSS APPLY (
    SELECT COUNT(DISTINCT fh.FormulaHeader) AS cnt
    FROM PR_FormulaHeader fh
    INNER JOIN PR_ProcessType pt
        ON fh.Proccestype = pt.ProcessType
       AND fh.Company = pt.Company
    WHERE fh.Company = @cia_origen
      AND pt.ShortName = 'LIQUIDACION'
) bgt
OUTER APPLY (
    SELECT COUNT(DISTINCT fh.FormulaHeader) AS cnt
    FROM PR_FormulaHeader fh
    INNER JOIN PR_ProcessType pt
        ON fh.Proccestype = pt.ProcessType
       AND fh.Company = pt.Company
    WHERE fh.Company = d.cia
      AND pt.ShortName = 'LIQUIDACION'
) dest
ORDER BY d.cia;

SELECT
    formulaheader_bgt,
    formulacode,
    estado,
    mensaje
FROM #ResultadoReplicaFormulas
WHERE estado = 'ERROR'
ORDER BY formulacode;

DROP TABLE #ResultadoReplicaFormulas;
