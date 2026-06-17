/*
    Alta / edición de concepto de planilla (PR_Concept) — maestro web.

    @modo: I = nuevo (genera Concept con sp_pr_genera_correlativo_web),
           U = actualizar registro existente.

    Campos expuestos en UI maestro Conceptos (Configuración).
    ConceptGroup se resuelve automáticamente al insertar si no se envía.

    Usado por: POST /api/conceptos/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarconcepto_web]
    @modo                 CHAR(1),
    @company              VARCHAR(4),
    @concept              VARCHAR(20) = NULL,
    @description          VARCHAR(50),
    @formulacode          VARCHAR(20),
    @concepttype          VARCHAR(20),
    @conceptgroup         VARCHAR(20) = NULL,
    @conceptcurrency      CHAR(2) = 'LO',
    @flagismonetary       CHAR(1) = 'Y',
    @printtext            VARCHAR(50) = NULL,
    @conceptorder         INT = NULL,
    @status               CHAR(1) = 'A',
    @flagassign           VARCHAR(1) = 'N',
    @flagpayrollticket    VARCHAR(1) = 'N',
    @flagcontract         CHAR(1) = 'N',
    @pdt                  VARCHAR(20) = NULL,
    @flagconceptdeclare   CHAR(1) = NULL,
    @reporden             INT = NULL,
    @flaginsertar         CHAR(1) = NULL,
    @flagafectoafp        CHAR(1) = NULL,
    @flagafecto5ta        CHAR(1) = NULL,
    @xlastuser            VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @concept_nuevo   VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @concept = NULLIF(LTRIM(RTRIM(ISNULL(@concept, ''))), '');
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @formulacode = UPPER(LTRIM(RTRIM(ISNULL(@formulacode, ''))));
    SET @concepttype = LTRIM(RTRIM(ISNULL(@concepttype, '')));
    SET @conceptgroup = NULLIF(LTRIM(RTRIM(ISNULL(@conceptgroup, ''))), '');
    SET @conceptcurrency = UPPER(LTRIM(RTRIM(ISNULL(@conceptcurrency, 'LO'))));
    SET @flagismonetary = UPPER(LTRIM(RTRIM(ISNULL(@flagismonetary, 'Y'))));
    SET @printtext = NULLIF(LTRIM(RTRIM(ISNULL(@printtext, ''))), '');
    SET @status = UPPER(LTRIM(RTRIM(ISNULL(@status, 'A'))));
    SET @flagassign = UPPER(LTRIM(RTRIM(ISNULL(@flagassign, 'N'))));
    SET @flagpayrollticket = UPPER(LTRIM(RTRIM(ISNULL(@flagpayrollticket, 'N'))));
    SET @flagcontract = UPPER(LTRIM(RTRIM(ISNULL(@flagcontract, 'N'))));
    SET @pdt = NULLIF(LTRIM(RTRIM(ISNULL(@pdt, ''))), '');
    SET @flagconceptdeclare = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flagconceptdeclare, '')))), '');
    SET @flaginsertar = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flaginsertar, '')))), '');
    SET @flagafectoafp = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flagafectoafp, '')))), '');
    SET @flagafecto5ta = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flagafecto5ta, '')))), '');
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
        RAISERROR('Indique la descripción del concepto.', 16, 1);
        RETURN;
    END;

    IF @formulacode = ''
    BEGIN
        RAISERROR('Indique el nemónico (FormulaCode).', 16, 1);
        RETURN;
    END;

    IF @concepttype = ''
    BEGIN
        RAISERROR('Indique el tipo de concepto.', 16, 1);
        RETURN;
    END;

    IF @flagismonetary = 'N'
        SET @conceptcurrency = 'LO';

    IF @conceptcurrency NOT IN ('LO', 'EX')
    BEGIN
        RAISERROR('Moneda inválida. Use LO o EX.', 16, 1);
        RETURN;
    END;

    IF @flagismonetary NOT IN ('Y', 'N')
    BEGIN
        RAISERROR('Valor monetario inválido. Use Y o N.', 16, 1);
        RETURN;
    END;

    IF @status NOT IN ('A', 'I')
    BEGIN
        RAISERROR('Estado inválido. Use A (activo) o I (inactivo).', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @concept IS NULL
    BEGIN
        RAISERROR('Indique el código del concepto a actualizar.', 16, 1);
        RETURN;
    END;

    IF @printtext IS NULL
        SET @printtext = @description;

    IF @reporden IS NULL
        SET @reporden = ISNULL(@conceptorder, 0);

    IF @flagconceptdeclare IS NULL
        SET @flagconceptdeclare = 'N';

    IF @flaginsertar IS NULL
        SET @flaginsertar = 'N';

    IF @flagafectoafp IS NULL
        SET @flagafectoafp = 'N';

    IF @flagafecto5ta IS NULL
        SET @flagafecto5ta = 'N';

    IF NOT EXISTS (
        SELECT 1 FROM PR_ConceptType (NOLOCK)
        WHERE ConceptType = @concepttype
    )
    BEGIN
        RAISERROR('Tipo de concepto inexistente.', 16, 1);
        RETURN;
    END;

    IF @conceptgroup IS NULL
    BEGIN
        SELECT TOP 1 @conceptgroup = C.ConceptGroup
        FROM PR_Concept C (NOLOCK)
        WHERE C.Company = @company
          AND C.ConceptType = @concepttype
        ORDER BY C.Concept;

        IF @conceptgroup IS NULL
        BEGIN
            SELECT TOP 1 @conceptgroup = C.ConceptGroup
            FROM PR_Concept C (NOLOCK)
            WHERE C.Company = @company
            ORDER BY C.Concept;
        END;

        IF @conceptgroup IS NULL
        BEGIN
            SELECT TOP 1 @conceptgroup = G.ConceptGroup
            FROM PR_ConceptGroup G (NOLOCK)
            ORDER BY G.ConceptGroup;
        END;
    END;

    IF @conceptgroup IS NULL OR NOT EXISTS (
        SELECT 1 FROM PR_ConceptGroup (NOLOCK)
        WHERE ConceptGroup = @conceptgroup
    )
    BEGIN
        RAISERROR('No se pudo determinar un grupo de concepto válido.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM PR_Concept (NOLOCK)
            WHERE Company = @company
              AND FormulaCode = @formulacode
        )
        BEGIN
            RAISERROR('Ya existe un concepto con el mismo nemónico en la compañía.', 16, 1);
            RETURN;
        END;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'PR_CONCEPT',
            @xlastuser = @xlastuser;

        SELECT @concept_nuevo = id_generado FROM @tabla_id;

        IF @concept_nuevo IS NULL OR LTRIM(RTRIM(@concept_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo del concepto.', 16, 1);
            RETURN;
        END;

        INSERT INTO PR_Concept (
            Concept,
            ConceptGroup,
            ConceptType,
            FormulaCode,
            ConceptOrder,
            Description,
            ConceptCurrency,
            FlagIsMonetary,
            PrintText,
            Flagassign,
            Status,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate,
            FLAGCONTRACT,
            FlagPayrollTicket,
            FLAGTEXTVALUEPRINT,
            pdt,
            flagconceptdeclare,
            RentOrder,
            PercentageDistribution,
            reporden,
            flaginsertar,
            flagafectoAFP,
            flagafecto5ta
        )
        VALUES (
            @concept_nuevo,
            @conceptgroup,
            @concepttype,
            @formulacode,
            @conceptorder,
            @description,
            @conceptcurrency,
            @flagismonetary,
            @printtext,
            @flagassign,
            @status,
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE(),
            @flagcontract,
            @flagpayrollticket,
            'X',
            @pdt,
            @flagconceptdeclare,
            0,
            'A',
            @reporden,
            @flaginsertar,
            @flagafectoafp,
            @flagafecto5ta
        );

        SELECT
            @concept_nuevo AS concept,
            'I' AS modo,
            'Concepto creado correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM PR_Concept (NOLOCK)
        WHERE Concept = @concept
          AND Company = @company
    )
    BEGIN
        RAISERROR('Concepto inexistente para la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1 FROM PR_Concept (NOLOCK)
        WHERE Company = @company
          AND FormulaCode = @formulacode
          AND Concept <> @concept
    )
    BEGIN
        RAISERROR('Ya existe otro concepto con el mismo nemónico en la compañía.', 16, 1);
        RETURN;
    END;

    UPDATE PR_Concept
    SET ConceptGroup = @conceptgroup,
        ConceptType = @concepttype,
        FormulaCode = @formulacode,
        ConceptOrder = @conceptorder,
        Description = @description,
        ConceptCurrency = @conceptcurrency,
        FlagIsMonetary = @flagismonetary,
        PrintText = @printtext,
        Flagassign = @flagassign,
        Status = @status,
        XLastUser = @xlastuser,
        XLastDate = GETDATE(),
        FLAGCONTRACT = @flagcontract,
        FlagPayrollTicket = @flagpayrollticket,
        pdt = @pdt,
        flagconceptdeclare = @flagconceptdeclare,
        reporden = @reporden,
        flaginsertar = @flaginsertar,
        flagafectoAFP = @flagafectoafp,
        flagafecto5ta = @flagafecto5ta
    WHERE Concept = @concept
      AND Company = @company;

    SELECT
        @concept AS concept,
        'U' AS modo,
        'Concepto actualizado correctamente.' AS mensaje;
END
GO
