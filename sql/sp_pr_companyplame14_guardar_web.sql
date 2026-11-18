/*
    Guarda (reemplaza) la configuración PLAME Archivo 14 de una compañía.

    @detalle_xml:
      <root>
        <l><line>1</line><type>WH</type><concept>xxx</concept><applysum>P</applysum></l>
        <l><line>1</line><type>HE</type><concept>yyy</concept><applysum>M</applysum></l>
      </root>

    Type: WH (horas ordinarias) | HE (horas extras)
    ApplySum: P (suma) | M (resta)

    Usado por: POST /api/plame/config-14/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_companyplame14_guardar_web]
    @cia         VARCHAR(4),
    @detalle_xml NVARCHAR(MAX) = NULL,
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @xlastuser = LEFT(NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), ''), 20);
    IF @xlastuser IS NULL SET @xlastuser = 'web';

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.SY_Company (NOLOCK) WHERE Company = @cia)
    BEGIN
        RAISERROR('La compañía no existe.', 16, 1);
        RETURN;
    END;

    IF @detalle_xml IS NULL OR LTRIM(RTRIM(@detalle_xml)) = ''
        SET @detalle_xml = N'<root></root>';

    DECLARE @xml XML = TRY_CAST(@detalle_xml AS XML);
    IF @xml IS NULL
    BEGIN
        RAISERROR('Detalle de configuración inválido.', 16, 1);
        RETURN;
    END;

    DECLARE @tmp TABLE (
        line      INT NOT NULL,
        typ       VARCHAR(2) NOT NULL,
        concept   VARCHAR(20) NOT NULL,
        applysum  CHAR(1) NOT NULL
    );

    INSERT INTO @tmp (line, typ, concept, applysum)
    SELECT
        ISNULL(TRY_CAST(x.value('(line)[1]', 'varchar(10)') AS INT), 0),
        UPPER(LTRIM(RTRIM(ISNULL(x.value('(type)[1]', 'varchar(2)'), '')))),
        LTRIM(RTRIM(ISNULL(x.value('(concept)[1]', 'varchar(20)'), ''))),
        UPPER(LEFT(LTRIM(RTRIM(ISNULL(x.value('(applysum)[1]', 'varchar(1)'), 'P'))), 1))
    FROM @xml.nodes('/root/l') AS T(x);

    IF EXISTS (SELECT 1 FROM @tmp WHERE typ NOT IN ('WH', 'HE'))
    BEGIN
        RAISERROR('Tipo inválido. Use WH o HE.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM @tmp WHERE applysum NOT IN ('P', 'M'))
    BEGIN
        RAISERROR('ApplySum inválido. Use P (suma) o M (resta).', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM @tmp WHERE concept = '')
    BEGIN
        RAISERROR('Todas las líneas deben tener un concepto.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM @tmp t
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.PR_Concept c (NOLOCK)
            WHERE c.Company = @cia
              AND c.Concept = t.concept
        )
    )
    BEGIN
        RAISERROR('Hay conceptos que no existen en la compañía.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT typ, concept
        FROM @tmp
        GROUP BY typ, concept
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Hay conceptos duplicados en el mismo tipo (WH/HE).', 16, 1);
        RETURN;
    END;

    /* Renumerar line por tipo */
    ;WITH ordered AS (
        SELECT
            concept,
            typ,
            applysum,
            ROW_NUMBER() OVER (
                PARTITION BY typ
                ORDER BY CASE WHEN line > 0 THEN line ELSE 9999 END, concept
            ) AS new_line
        FROM @tmp
    )
    UPDATE t
    SET line = o.new_line
    FROM @tmp t
    INNER JOIN ordered o
        ON o.typ = t.typ
       AND o.concept = t.concept;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM dbo.PR_CompanyPlame
        WHERE Company = @cia
          AND LTRIM(RTRIM(ISNULL(Plame, ''))) = '14';

        INSERT INTO dbo.PR_CompanyPlame
            (Company, line, Plame, Concept, Type, ApplySum, XLastUser, XLastDate)
        SELECT
            @cia,
            t.line,
            '14',
            t.concept,
            t.typ,
            t.applysum,
            @xlastuser,
            GETDATE()
        FROM @tmp t
        ORDER BY t.typ, t.line;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
        RETURN;
    END CATCH;

    SELECT
        CAST(1 AS BIT) AS ok,
        (SELECT COUNT(*) FROM @tmp) AS total,
        (SELECT COUNT(*) FROM @tmp WHERE typ = 'WH') AS total_wh,
        (SELECT COUNT(*) FROM @tmp WHERE typ = 'HE') AS total_he,
        N'Configuración PLAME 14 guardada correctamente.' AS mensaje;
END
GO
