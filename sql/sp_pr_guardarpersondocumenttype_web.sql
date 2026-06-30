/*
    Alta / edición de SY_PersonDocumentType — maestro web Tipos de Documentos.

    @modo: I = nuevo (genera PersonDocumentType con sp_pr_genera_correlativo_web / PR_PERSONDOCUMENTYPE),
           U = actualizar registro existente.

    Usado por: POST /api/tipos-documento/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarpersondocumenttype_web]
    @modo                 CHAR(1),
    @company              VARCHAR(4),
    @persondocumenttype   VARCHAR(20) = NULL,
    @description          VARCHAR(50),
    @pdt                  VARCHAR(20),
    @xlastuser            VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @tipo_nuevo      VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @persondocumenttype = NULLIF(LTRIM(RTRIM(ISNULL(@persondocumenttype, ''))), '');
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @pdt = LTRIM(RTRIM(ISNULL(@pdt, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @description = ''
    BEGIN
        RAISERROR('Indique la descripción del tipo de documento.', 16, 1);
        RETURN;
    END;

    IF @pdt = ''
    BEGIN
        RAISERROR('Indique el código PDT.', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @persondocumenttype IS NULL
    BEGIN
        RAISERROR('Indique el tipo de documento a actualizar.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM SY_PersonDocumentType (NOLOCK)
            WHERE Company = @company
              AND LTRIM(RTRIM(ISNULL(Description, ''))) = @description
        )
        BEGIN
            RAISERROR('Ya existe un tipo de documento con la misma descripción para la compañía.', 16, 1);
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM SY_PersonDocumentType (NOLOCK)
            WHERE Company = @company
              AND LTRIM(RTRIM(ISNULL(PDT, ''))) = @pdt
        )
        BEGIN
            RAISERROR('Ya existe un tipo de documento con el mismo código PDT para la compañía.', 16, 1);
            RETURN;
        END;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'PR_PERSONDOCUMENTYPE',
            @xlastuser = @xlastuser;

        SELECT @tipo_nuevo = id_generado FROM @tabla_id;

        IF @tipo_nuevo IS NULL OR LTRIM(RTRIM(@tipo_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo del tipo de documento.', 16, 1);
            RETURN;
        END;

        INSERT INTO SY_PersonDocumentType (
            PersonDocumentType,
            Description,
            PDT,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate
        )
        VALUES (
            @tipo_nuevo,
            @description,
            @pdt,
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE()
        );

        SELECT
            @tipo_nuevo AS persondocumenttype,
            'Tipo de documento registrado correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM SY_PersonDocumentType (NOLOCK)
        WHERE Company = @company
          AND PersonDocumentType = @persondocumenttype
    )
    BEGIN
        RAISERROR('No se encontró el tipo de documento a actualizar.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM SY_PersonDocumentType (NOLOCK)
        WHERE Company = @company
          AND LTRIM(RTRIM(ISNULL(Description, ''))) = @description
          AND PersonDocumentType <> @persondocumenttype
    )
    BEGIN
        RAISERROR('Ya existe otro tipo de documento con la misma descripción para la compañía.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM SY_PersonDocumentType (NOLOCK)
        WHERE Company = @company
          AND LTRIM(RTRIM(ISNULL(PDT, ''))) = @pdt
          AND PersonDocumentType <> @persondocumenttype
    )
    BEGIN
        RAISERROR('Ya existe otro tipo de documento con el mismo código PDT para la compañía.', 16, 1);
        RETURN;
    END;

    UPDATE SY_PersonDocumentType
    SET Description = @description,
        PDT = @pdt,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND PersonDocumentType = @persondocumenttype;

    SELECT
        @persondocumenttype AS persondocumenttype,
        'Tipo de documento actualizado correctamente.' AS mensaje;
END
GO
