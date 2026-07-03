/*
    Replica fórmulas LIQUIDACIÓN de BGT hacia todas las demás empresas
    usando sp_pr_replicar_formula_cia (replica por FormulaHeader origen).

    Requisito previo: conceptos replicados en destino (mismo FormulaCode).

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @cia_origen     VARCHAR(20) = 'BGT';
DECLARE @formulaheader  VARCHAR(20);
DECLARE @formulacode    VARCHAR(50);
DECLARE @total          INT = 0;
DECLARE @replicados     INT = 0;
DECLARE @errores        INT = 0;

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
    WHERE fh.Company = @cia_origen
      AND pt.ShortName = 'LIQUIDACION'
    ORDER BY fh.FormulaHeader;

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
    COUNT(DISTINCT fh.formulacode) AS formulas_bgt,
    COUNT(DISTINCT fd.formulacode) AS formulas_destino,
    COUNT(DISTINCT fh.formulacode) - COUNT(DISTINCT fd.formulacode) AS faltantes
FROM (VALUES ('SB01'), ('SB02'), ('SB03'), ('SB04'), ('SB05'), ('SB06')) AS d(cia)
CROSS JOIN PR_FormulaHeader fh
INNER JOIN PR_ProcessType pt
    ON fh.Proccestype = pt.ProcessType
LEFT JOIN PR_FormulaHeader fd
    ON fd.Company = d.cia
   AND fd.formulacode = fh.formulacode
LEFT JOIN PR_ProcessType ptd
    ON fd.Proccestype = ptd.ProcessType
   AND ptd.ShortName = 'LIQUIDACION'
WHERE fh.Company = @cia_origen
  AND pt.ShortName = 'LIQUIDACION'
  AND fh.formulacode IS NOT NULL
  AND LTRIM(RTRIM(fh.formulacode)) <> ''
GROUP BY d.cia
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
