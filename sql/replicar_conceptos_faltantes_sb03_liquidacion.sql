/*
    Replica a SB03 los conceptos faltantes (por FormulaCode / nemónico)
    requeridos por fórmulas LIQUIDACIÓN de BGT.

    Usa: sp_pr_replicar_nuevo_concepto_nemonico
    Origen del concepto: PR_Concept (Company = 'BGT') en hm_aci
    Destino: PR_Concept (Company = 'SB03') en hm_aci

    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @cia_destino   VARCHAR(20) = 'SB03';
DECLARE @cia_origen    VARCHAR(20) = 'BGT';
DECLARE @formulacode   VARCHAR(50);
DECLARE @concept_creado VARCHAR(20);
DECLARE @total         INT = 0;
DECLARE @replicados    INT = 0;
DECLARE @omitidos      INT = 0;
DECLARE @errores       INT = 0;

IF OBJECT_ID('tempdb..#ResultadoReplicaConceptos') IS NOT NULL
    DROP TABLE #ResultadoReplicaConceptos;

CREATE TABLE #ResultadoReplicaConceptos (
    formulacode   VARCHAR(50)  NOT NULL,
    estado        VARCHAR(20)  NOT NULL,
    concept_sb03  VARCHAR(20)  NULL,
    mensaje       VARCHAR(255) NULL
);

DECLARE cur_conceptos CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT fh.formulacode
    FROM PR_FormulaHeader fh
    INNER JOIN PR_ProcessType pt
        ON fh.Proccestype = pt.ProcessType
    WHERE fh.Company = @cia_origen
      AND pt.ShortName = 'LIQUIDACION'
      AND fh.formulacode IS NOT NULL
      AND LTRIM(RTRIM(fh.formulacode)) <> ''
      AND NOT EXISTS (
            SELECT 1
            FROM PR_Concept c
            WHERE c.Company = @cia_destino
              AND c.FormulaCode = fh.formulacode
      )
    ORDER BY fh.formulacode;

OPEN cur_conceptos;
FETCH NEXT FROM cur_conceptos INTO @formulacode;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @total += 1;

    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1
            FROM PR_Concept
            WHERE Company = @cia_origen
              AND FormulaCode = @formulacode
        )
        BEGIN
            INSERT INTO #ResultadoReplicaConceptos (formulacode, estado, mensaje)
            VALUES (@formulacode, 'ERROR', 'No existe en PR_Concept (BGT) en hm_aci');
            SET @errores += 1;
        END
        ELSE IF EXISTS (
            SELECT 1
            FROM PR_Concept
            WHERE Company = @cia_destino
              AND FormulaCode = @formulacode
        )
        BEGIN
            INSERT INTO #ResultadoReplicaConceptos (formulacode, estado, concept_sb03, mensaje)
            SELECT
                @formulacode,
                'OMITIDO',
                c.Concept,
                'Ya existía en destino'
            FROM PR_Concept c
            WHERE c.Company = @cia_destino
              AND c.FormulaCode = @formulacode;

            SET @omitidos += 1;
        END
        ELSE
        BEGIN
            EXEC dbo.sp_pr_replicar_nuevo_concepto_nemonico
                @cia = @cia_destino,
                @formulacode = @formulacode,
                @cia_origen = @cia_origen;

            SET @concept_creado = NULL;
            SELECT @concept_creado = c.Concept
            FROM PR_Concept c
            WHERE c.Company = @cia_destino
              AND c.FormulaCode = @formulacode;

            IF @concept_creado IS NOT NULL
            BEGIN
                INSERT INTO #ResultadoReplicaConceptos (formulacode, estado, concept_sb03, mensaje)
                SELECT @formulacode, 'REPLICADO', c.Concept, c.Description
                FROM PR_Concept c
                WHERE c.Company = @cia_destino
                  AND c.FormulaCode = @formulacode;

                SET @replicados += 1;
            END
            ELSE
            BEGIN
                INSERT INTO #ResultadoReplicaConceptos (formulacode, estado, mensaje)
                VALUES (@formulacode, 'ERROR', 'SP ejecutado pero no se creó concepto en destino');

                SET @errores += 1;
            END
        END
    END TRY
    BEGIN CATCH
        INSERT INTO #ResultadoReplicaConceptos (formulacode, estado, mensaje)
        VALUES (@formulacode, 'ERROR', ERROR_MESSAGE());
        SET @errores += 1;
    END CATCH;

    FETCH NEXT FROM cur_conceptos INTO @formulacode;
END;

CLOSE cur_conceptos;
DEALLOCATE cur_conceptos;

/* Nemónicos usados directamente en sp_pr_calcular_liquidacion_persona (no siempre en PR_FormulaHeader). */
DECLARE @hardcoded TABLE (formulacode VARCHAR(50) NOT NULL);
INSERT INTO @hardcoded (formulacode) VALUES ('DIASVACPAG');

DECLARE cur_hardcoded CURSOR LOCAL FAST_FORWARD FOR
    SELECT h.formulacode
    FROM @hardcoded h
    WHERE NOT EXISTS (
        SELECT 1 FROM PR_Concept c
        WHERE c.Company = @cia_destino AND c.FormulaCode = h.formulacode
    );

OPEN cur_hardcoded;
FETCH NEXT FROM cur_hardcoded INTO @formulacode;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @total += 1;
    BEGIN TRY
        EXEC dbo.sp_pr_replicar_nuevo_concepto_nemonico
            @cia = @cia_destino,
            @formulacode = @formulacode,
            @cia_origen = @cia_origen;

        SET @concept_creado = (
            SELECT TOP 1 c.Concept
            FROM PR_Concept c
            WHERE c.Company = @cia_destino AND c.FormulaCode = @formulacode
        );

        IF @concept_creado IS NOT NULL
        BEGIN
            INSERT INTO #ResultadoReplicaConceptos (formulacode, estado, concept_sb03, mensaje)
            SELECT @formulacode, 'REPLICADO', c.Concept, c.Description
            FROM PR_Concept c
            WHERE c.Company = @cia_destino AND c.FormulaCode = @formulacode;
            SET @replicados += 1;
        END
    END TRY
    BEGIN CATCH
        INSERT INTO #ResultadoReplicaConceptos (formulacode, estado, mensaje)
        VALUES (@formulacode, 'ERROR', ERROR_MESSAGE());
        SET @errores += 1;
    END CATCH;

    FETCH NEXT FROM cur_hardcoded INTO @formulacode;
END;

CLOSE cur_hardcoded;
DEALLOCATE cur_hardcoded;

SELECT
    @total      AS total_procesados,
    @replicados  AS replicados,
    @omitidos    AS omitidos,
    @errores     AS errores;

SELECT
    formulacode,
    estado,
    concept_sb03,
    mensaje
FROM #ResultadoReplicaConceptos
ORDER BY
    CASE estado WHEN 'ERROR' THEN 1 WHEN 'REPLICADO' THEN 2 ELSE 3 END,
    formulacode;

DROP TABLE #ResultadoReplicaConceptos;
