/*
    Alta / edición de plantilla de importación de conceptos (cabecera + detalle XML).

    @modo: I = nuevo (genera ImportConcept con sp_pr_genera_correlativo_web / PR_IMPORTCONCEPT),
           U = actualizar.

    @detalle_xml: <root><l><line>1</line><concept>...</concept><description>...</description></l></root>

    Usado por: POST /api/plantillas-importacion/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarimportconcept_web]
    @modo          CHAR(1),
    @company       VARCHAR(4),
    @importconcept VARCHAR(20) = NULL,
    @name          VARCHAR(50),
    @detalle_xml   NVARCHAR(MAX) = NULL,
    @xlastuser     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @id_generado     VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @importconcept = NULLIF(LTRIM(RTRIM(ISNULL(@importconcept, ''))), '');
    SET @name = LTRIM(RTRIM(ISNULL(@name, '')));
    SET @xlastuser = LEFT(NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), ''), 20);

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @name = ''
    BEGIN
        RAISERROR('Indique el nombre de la plantilla.', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @importconcept IS NULL
    BEGIN
        RAISERROR('Indique la plantilla a actualizar.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_ImportConcept ic (NOLOCK)
        WHERE ic.Company = @company
          AND UPPER(LTRIM(RTRIM(ic.Name))) = UPPER(@name)
          AND (@modo = 'I' OR ic.ImportConcept <> @importconcept)
    )
    BEGIN
        RAISERROR('Ya existe una plantilla con el mismo nombre en la compañía.', 16, 1);
        RETURN;
    END;

    DECLARE @cnt_detalle INT = 0;

    IF @detalle_xml IS NULL OR LTRIM(RTRIM(@detalle_xml)) = ''
    BEGIN
        RAISERROR('La plantilla debe tener al menos un concepto asociado.', 16, 1);
        RETURN;
    END;

    DECLARE @xml_val XML = TRY_CAST(@detalle_xml AS XML);

    IF @xml_val IS NULL
    BEGIN
        RAISERROR('Detalle de plantilla inválido.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM @xml_val.nodes('/root/l') AS T(x)
        WHERE NULLIF(LTRIM(RTRIM(x.value('(concept)[1]', 'varchar(20)'))), '') IS NULL
    )
    BEGIN
        RAISERROR('Todas las líneas del detalle deben tener un concepto asociado.', 16, 1);
        RETURN;
    END;

    SELECT @cnt_detalle = COUNT(*)
    FROM @xml_val.nodes('/root/l') AS T(x)
    WHERE NULLIF(LTRIM(RTRIM(x.value('(concept)[1]', 'varchar(20)'))), '') IS NOT NULL;

    IF @cnt_detalle < 1
    BEGIN
        RAISERROR('La plantilla debe tener al menos un concepto asociado.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @modo = 'I'
        BEGIN
            INSERT INTO @tabla_id (id_generado)
            EXEC dbo.sp_pr_genera_correlativo_web
                @cia = @company,
                @object = 'PR_IMPORTCONCEPT',
                @xlastuser = @xlastuser;

            SELECT TOP 1 @id_generado = id_generado FROM @tabla_id;

            IF @id_generado IS NULL OR LTRIM(RTRIM(@id_generado)) = ''
            BEGIN
                RAISERROR('No se pudo generar el correlativo de la plantilla.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;

            SET @importconcept = @id_generado;

            INSERT INTO PR_ImportConcept (
                ImportConcept, Name, Company, ReplicationUnit, XlastUser, XlastDate
            )
            VALUES (
                @importconcept, @name, @company, @replicationunit, @xlastuser, GETDATE()
            );
        END
        ELSE
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM PR_ImportConcept (NOLOCK)
                WHERE Company = @company AND ImportConcept = @importconcept
            )
            BEGIN
                RAISERROR('Plantilla no encontrada.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;

            UPDATE PR_ImportConcept
            SET Name = @name,
                XlastUser = @xlastuser,
                XlastDate = GETDATE()
            WHERE Company = @company
              AND ImportConcept = @importconcept;
        END;

        /* Legacy: Detail.Company puede ser NULL; borrar por ImportConcept + cia/vacío. */
        DELETE FROM PR_ImportConceptDetail
        WHERE ImportConcept = @importconcept
          AND (
                Company = @company
             OR Company IS NULL
             OR LTRIM(RTRIM(Company)) = ''
          );

        IF @detalle_xml IS NOT NULL AND LTRIM(RTRIM(@detalle_xml)) <> ''
        BEGIN
            DECLARE @xml XML = TRY_CAST(@detalle_xml AS XML);
            IF @xml IS NOT NULL
            BEGIN
                INSERT INTO PR_ImportConceptDetail (
                    ImportConcept, Line, Concept, Description, Company,
                    ReplicationUnit, XlastUser, XlastDate
                )
                SELECT
                    @importconcept,
                    ISNULL(NULLIF(x.value('(line)[1]', 'int'), 0), ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
                    LEFT(NULLIF(LTRIM(RTRIM(x.value('(concept)[1]', 'varchar(20)'))), ''), 20),
                    LEFT(NULLIF(LTRIM(RTRIM(x.value('(description)[1]', 'varchar(100)'))), ''), 50),
                    @company,
                    @replicationunit,
                    @xlastuser,
                    GETDATE()
                FROM @xml.nodes('/root/l') AS T(x)
                WHERE NULLIF(LTRIM(RTRIM(x.value('(concept)[1]', 'varchar(20)'))), '') IS NOT NULL;
            END;
        END;

        COMMIT TRANSACTION;

        SELECT
            @importconcept AS importconcept,
            @modo AS modo,
            'Guardado correctamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
