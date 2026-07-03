/*
    Replica conceptos faltantes (por FormulaCode / nemónico) desde BGT
    hacia SB01–SB06, requeridos por fórmulas de:
      - PROVISION CTS
      - PROVISION GRATIFICACION
      - PROVISION VACACIONES

    Usa: sp_pr_replicar_nuevo_concepto_nemonico
    Ejecutar en: hm_aci
*/
SET NOCOUNT ON;

DECLARE @cia_origen VARCHAR(20) = 'BGT';

DECLARE @empresas_destino TABLE (cia VARCHAR(20) NOT NULL PRIMARY KEY);
INSERT INTO @empresas_destino (cia) VALUES
    ('SB01'), ('SB02'), ('SB03'), ('SB04'), ('SB05'), ('SB06');

DECLARE @procesos_origen TABLE (shortname VARCHAR(50) NOT NULL PRIMARY KEY);
INSERT INTO @procesos_origen (shortname) VALUES
    ('PROVISION_CTS'),
    ('PROVISION_VACACIONES'),
    ('PROVISION_GRATIF');

DECLARE @cia_destino    VARCHAR(20);
DECLARE @formulacode    VARCHAR(50);
DECLARE @concept_creado VARCHAR(20);
DECLARE @total          INT = 0;
DECLARE @replicados     INT = 0;
DECLARE @omitidos       INT = 0;
DECLARE @errores        INT = 0;

IF OBJECT_ID('tempdb..#ResultadoReplicaConceptos') IS NOT NULL
    DROP TABLE #ResultadoReplicaConceptos;

CREATE TABLE #ResultadoReplicaConceptos (
    company       VARCHAR(20)  NOT NULL,
    formulacode   VARCHAR(50)  NOT NULL,
    estado        VARCHAR(20)  NOT NULL,
    concept_dest  VARCHAR(20)  NULL,
    mensaje       VARCHAR(255) NULL
);

DECLARE cur_empresas CURSOR LOCAL FAST_FORWARD FOR
    SELECT cia FROM @empresas_destino ORDER BY cia;

OPEN cur_empresas;
FETCH NEXT FROM cur_empresas INTO @cia_destino;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE cur_conceptos CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT fh.formulacode
        FROM PR_FormulaHeader fh
        INNER JOIN PR_ProcessType pt
            ON fh.Proccestype = pt.ProcessType
           AND fh.Company = pt.Company
        INNER JOIN @procesos_origen po
            ON pt.ShortName = po.shortname
        WHERE fh.Company = @cia_origen
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
                INSERT INTO #ResultadoReplicaConceptos (company, formulacode, estado, mensaje)
                VALUES (@cia_destino, @formulacode, 'ERROR', 'No existe en PR_Concept (BGT) en hm_aci');
                SET @errores += 1;
            END
            ELSE IF EXISTS (
                SELECT 1
                FROM PR_Concept
                WHERE Company = @cia_destino
                  AND FormulaCode = @formulacode
            )
            BEGIN
                INSERT INTO #ResultadoReplicaConceptos (company, formulacode, estado, concept_dest, mensaje)
                SELECT
                    @cia_destino,
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
                    INSERT INTO #ResultadoReplicaConceptos (company, formulacode, estado, concept_dest, mensaje)
                    SELECT @cia_destino, @formulacode, 'REPLICADO', c.Concept, c.Description
                    FROM PR_Concept c
                    WHERE c.Company = @cia_destino
                      AND c.FormulaCode = @formulacode;

                    SET @replicados += 1;
                END
                ELSE
                BEGIN
                    INSERT INTO #ResultadoReplicaConceptos (company, formulacode, estado, mensaje)
                    VALUES (@cia_destino, @formulacode, 'ERROR', 'SP ejecutado pero no se creó concepto en destino');

                    SET @errores += 1;
                END
            END
        END TRY
        BEGIN CATCH
            INSERT INTO #ResultadoReplicaConceptos (company, formulacode, estado, mensaje)
            VALUES (@cia_destino, @formulacode, 'ERROR', ERROR_MESSAGE());
            SET @errores += 1;
        END CATCH;

        FETCH NEXT FROM cur_conceptos INTO @formulacode;
    END;

    CLOSE cur_conceptos;
    DEALLOCATE cur_conceptos;

    FETCH NEXT FROM cur_empresas INTO @cia_destino;
END;

CLOSE cur_empresas;
DEALLOCATE cur_empresas;

SELECT
    @total      AS total_procesados,
    @replicados  AS replicados,
    @omitidos    AS omitidos,
    @errores     AS errores;

SELECT
    company,
    COUNT(*) AS total,
    SUM(CASE WHEN estado = 'REPLICADO' THEN 1 ELSE 0 END) AS replicados,
    SUM(CASE WHEN estado = 'OMITIDO' THEN 1 ELSE 0 END) AS omitidos,
    SUM(CASE WHEN estado = 'ERROR' THEN 1 ELSE 0 END) AS errores
FROM #ResultadoReplicaConceptos
GROUP BY company
ORDER BY company;

SELECT
    company,
    formulacode,
    estado,
    concept_dest,
    mensaje
FROM #ResultadoReplicaConceptos
WHERE estado = 'ERROR'
ORDER BY company, formulacode;

DROP TABLE #ResultadoReplicaConceptos;
