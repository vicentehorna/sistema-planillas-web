/*
    Alta / edición de fórmula (cabecera + detalle XML).
    @modo: I = nuevo, U = actualizar.
    @detalle_xml: <root><l><line>1</line><tipo>A</tipo>...</l></root>

    Usado por: POST /api/formulas/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarformula_web]
    @modo                 CHAR(1),
    @company              VARCHAR(4),
    @formulaheader        VARCHAR(20) = NULL,
    @payrolltype          VARCHAR(20),
    @proccestype          VARCHAR(20),
    @concept              VARCHAR(20),
    @description          VARCHAR(255) = NULL,
    @orden                INT = NULL,
    @person               VARCHAR(20) = NULL,
    @period               VARCHAR(20) = NULL,
    @tipo                 CHAR(1) = NULL,
    @conceptcond          VARCHAR(20) = NULL,
    @grupoformula         VARCHAR(20) = NULL,
    @flagtruncate         CHAR(1) = 'N',
    @formulacode          VARCHAR(50) = NULL,
    @parametroformula     VARCHAR(20) = NULL,
    @detalle_xml          NVARCHAR(MAX) = NULL,
    @xlastuser            VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_generado VARCHAR(20);
    DECLARE @tabla_id    TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @formulaheader = NULLIF(LTRIM(RTRIM(ISNULL(@formulaheader, ''))), '');
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @proccestype = LTRIM(RTRIM(ISNULL(@proccestype, '')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '')));
    SET @description = NULLIF(LTRIM(RTRIM(ISNULL(@description, ''))), '');
    SET @person = NULLIF(LTRIM(RTRIM(ISNULL(@person, ''))), '');
    SET @period = NULLIF(LTRIM(RTRIM(ISNULL(@period, ''))), '');
    SET @tipo = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@tipo, '')))), '');
    SET @conceptcond = NULLIF(LTRIM(RTRIM(ISNULL(@conceptcond, ''))), '');
    SET @grupoformula = NULLIF(LTRIM(RTRIM(ISNULL(@grupoformula, ''))), '');
    SET @flagtruncate = UPPER(LTRIM(RTRIM(ISNULL(@flagtruncate, 'N'))));
    SET @formulacode = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@formulacode, '')))), '');
    SET @parametroformula = NULLIF(LTRIM(RTRIM(ISNULL(@parametroformula, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo inválido. Use I o U.', 16, 1);
        RETURN;
    END;

    IF @company = '' OR @payrolltype = '' OR @proccestype = '' OR @concept = ''
    BEGIN
        RAISERROR('Complete compañía, planilla, proceso y concepto.', 16, 1);
        RETURN;
    END;

    /* Cabecera: el concepto debe tener Insertar en = Ninguno (flaginsertar = N). */
    DECLARE @flag_insertar CHAR(1);
    DECLARE @concept_desc  VARCHAR(255);
    DECLARE @insertar_txt  VARCHAR(40);

    SELECT
        @flag_insertar = UPPER(LTRIM(RTRIM(ISNULL(flaginsertar, 'N')))),
        @concept_desc = LTRIM(RTRIM(ISNULL(Description, FormulaCode)))
    FROM PR_Concept (NOLOCK)
    WHERE Company = @company
      AND Concept = @concept;

    IF @flag_insertar IS NULL
    BEGIN
        RAISERROR('El concepto de la cabecera no existe en el maestro de conceptos.', 16, 1);
        RETURN;
    END;

    IF @flag_insertar = ''
        SET @flag_insertar = 'N';

    IF @flag_insertar <> 'N'
    BEGIN
        SET @insertar_txt = CASE @flag_insertar
            WHEN 'M' THEN 'Mensual'
            WHEN 'Q' THEN 'Quincena'
            WHEN 'L' THEN 'Liquidación'
            WHEN 'G' THEN 'Gratificación'
            WHEN 'S' THEN 'Semanal'
            WHEN 'V' THEN 'Vacaciones'
            ELSE @flag_insertar
        END;
        /* Mensaje sin acentos: el ODBC/latin1 corrompe UTF-8 en RAISERROR. */
        RAISERROR(
            'El concepto de la cabecera ("%s") debe tener Insertar en = Ninguno en el maestro de conceptos. Actualmente esta en: %s. Corrija el concepto o cambie Insertar en a Ninguno antes de grabar la formula.',
            16, 1, @concept_desc, @insertar_txt);
        RETURN;
    END;

    /* Concepto de cabecera unico por empresa / planilla / proceso. */
    IF EXISTS (
        SELECT 1
        FROM PR_FormulaHeader fh (NOLOCK)
        WHERE fh.Company = @company
          AND fh.Payrolltype = @payrolltype
          AND fh.Proccestype = @proccestype
          AND fh.Concept = @concept
          AND (
                @modo = 'I'
                OR @formulaheader IS NULL
                OR fh.FormulaHeader <> @formulaheader
              )
    )
    BEGIN
        /* Mensaje sin acentos: el ODBC/latin1 corrompe UTF-8 en RAISERROR. */
        RAISERROR(
            'Ya existe otra formula asociada al concepto "%s" en la misma empresa, planilla y proceso. Cambie el concepto de la cabecera antes de guardar.',
            16, 1, @concept_desc);
        RETURN;
    END;

    IF @tipo = 'N'
        SET @conceptcond = NULL;
    IF @tipo <> 'V'
        SET @parametroformula = NULL;

    IF @formulacode IS NULL
    BEGIN
        SELECT @formulacode = UPPER(LTRIM(RTRIM(ISNULL(FormulaCode, ''))))
        FROM PR_Concept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept;
        SET @formulacode = NULLIF(@formulacode, '');
    END;

    IF @flagtruncate NOT IN ('Y', 'N')
        SET @flagtruncate = 'N';

    DECLARE @xml XML = NULL;
    DECLARE @cant_detalle INT = 0;

    IF @detalle_xml IS NOT NULL AND LTRIM(RTRIM(@detalle_xml)) <> ''
        SET @xml = TRY_CAST(@detalle_xml AS XML);

    IF @xml IS NOT NULL
        SET @cant_detalle = ISNULL(@xml.value('count(/root/l)', 'int'), 0);

    IF ISNULL(@cant_detalle, 0) = 0
    BEGIN
        RAISERROR('La fórmula debe tener al menos una línea de detalle.', 16, 1);
        RETURN;
    END;

    /* Validación de construcción (evita SQL dinámico inválido en SP_PR_EjecutarFormula). */
    IF ISNULL(@tipo, 'N') IN ('A', 'C') AND @conceptcond IS NULL
    BEGIN
        RAISERROR(
            'Si el tipo de cabecera es Concepto o Asignación, indique el concepto condicional. Si no usa condición, elija tipo Ninguno.',
            16, 1);
        RETURN;
    END;

    DECLARE @det TABLE (
        idx       INT IDENTITY(1, 1) PRIMARY KEY,
        line_no   INT NOT NULL,
        tipo      CHAR(1) NULL,
        operador  CHAR(1) NULL,
        grupo     CHAR(1) NULL
    );

    INSERT INTO @det (line_no, tipo, operador, grupo)
    SELECT
        ISNULL(NULLIF(x.value('(line)[1]', 'int'), 0), ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(tipo)[1]', 'varchar(5)')))), ''),
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(operador)[1]', 'varchar(5)')))), ''),
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(grupo)[1]', 'varchar(5)')))), '')
    FROM @xml.nodes('/root/l') AS T(x)
    ORDER BY ISNULL(NULLIF(x.value('(line)[1]', 'int'), 0), 2147483647);

    DECLARE
        @i INT = 1,
        @n INT = (SELECT COUNT(*) FROM @det),
        @t1 CHAR(1),
        @t2 CHAR(1),
        @o1 CHAR(1),
        @g1 CHAR(1),
        @g2 CHAR(1),
        @ln1 INT;

    WHILE @i < @n
    BEGIN
        SELECT @t1 = tipo, @o1 = operador, @g1 = grupo, @ln1 = line_no
        FROM @det WHERE idx = @i;

        SELECT @t2 = tipo, @g2 = grupo
        FROM @det WHERE idx = @i + 1;

        /* Operador ES (T) separa rama THEN/ELSE: no exige aritmética hacia la siguiente. */
            IF ISNULL(@o1, '') = 'T'
        BEGIN
            SET @i = @i + 1;
            CONTINUE;
        END;

        /* '(' no es un importe; no validar concatenación contra la siguiente. */
        IF @t1 = 'G' AND ISNULL(@g1, '') = 'O'
        BEGIN
            SET @i = @i + 1;
            CONTINUE;
        END;

        /* Cierre/apertura de grupo: patrón legacy "valor () + Grupo"; no es el bug .0000. */
        IF @t2 = 'G'
        BEGIN
            SET @i = @i + 1;
            CONTINUE;
        END;

        IF ISNULL(@t1, '') IN ('A', 'P', 'C', 'S', 'I', 'B', 'R', 'M', 'H', 'U', 'V', 'T', 'X', 'Y', 'Z', 'K')
           AND ISNULL(@t2, '') IN ('A', 'P', 'C', 'S', 'I', 'B', 'R', 'M', 'H', 'U', 'V', 'T', 'X', 'Y', 'Z', 'K')
           AND ISNULL(@o1, '') NOT IN ('M', 'P', 'X', 'D')
        BEGIN
            RAISERROR(
                'Línea %d: falta operador (+, -, *, /) antes de la siguiente línea de valor. Sin operador el motor concatena los importes y falla al calcular (p.ej. Incorrect syntax near ''.0000''). Use () solo en la última línea.',
                16, 1, @ln1);
            RETURN;
        END;

        SET @i = @i + 1;
    END;

    /* Tipo K (Código): debe traer expresión compilada; se recomienda una sola línea K. */
    IF EXISTS (
        SELECT 1
        FROM @xml.nodes('/root/l') AS T(x)
        WHERE UPPER(LTRIM(RTRIM(ISNULL(x.value('(tipo)[1]', 'varchar(5)'), '')))) = 'K'
          AND (
                NULLIF(LTRIM(RTRIM(x.value('(compiledexpr)[1]', 'nvarchar(max)'))), '') IS NULL
            )
    )
    BEGIN
        RAISERROR('Línea Código (K): falta la expresión compilada. Valide el código antes de guardar.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @modo = 'I'
        BEGIN
            INSERT INTO @tabla_id (id_generado)
            EXEC sp_pr_genera_correlativo_web
                @cia = @company,
                @object = 'PRA_FORM2024',
                @xlastuser = @xlastuser;

            SELECT TOP 1 @id_generado = id_generado FROM @tabla_id;
            IF @id_generado IS NULL OR @id_generado = ''
            BEGIN
                RAISERROR('No se pudo generar el ID de fórmula.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;

            SET @formulaheader = @id_generado;

            INSERT INTO PR_FormulaHeader (
                FormulaHeader, Company, Payrolltype, Proccestype, Concept, Description,
                orden, XLastUser, XLastDate, person, period, Tipo, ConceptCond,
                GrupoFormula, flagtruncate, formulacode, parametroformula
            )
            VALUES (
                @formulaheader, @company, @payrolltype, @proccestype, @concept, ISNULL(@description, ''),
                ISNULL(@orden, 0), @xlastuser, GETDATE(), @person, @period, @tipo, @conceptcond,
                @grupoformula, @flagtruncate, @formulacode, @parametroformula
            );
        END
        ELSE
        BEGIN
            IF @formulaheader IS NULL
            BEGIN
                RAISERROR('Indique la fórmula a actualizar.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;

            IF NOT EXISTS (
                SELECT 1 FROM PR_FormulaHeader (NOLOCK)
                WHERE Company = @company AND FormulaHeader = @formulaheader
            )
            BEGIN
                RAISERROR('Fórmula no encontrada.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;

            UPDATE PR_FormulaHeader
            SET Payrolltype = @payrolltype,
                Proccestype = @proccestype,
                Concept = @concept,
                Description = ISNULL(@description, ''),
                orden = ISNULL(@orden, 0),
                XLastUser = @xlastuser,
                XLastDate = GETDATE(),
                person = @person,
                period = @period,
                Tipo = @tipo,
                ConceptCond = @conceptcond,
                GrupoFormula = @grupoformula,
                flagtruncate = @flagtruncate,
                formulacode = @formulacode,
                parametroformula = @parametroformula
            WHERE Company = @company
              AND FormulaHeader = @formulaheader;
        END;

        DELETE FROM PR_FormulaDetail
        WHERE FormulaHeader = @formulaheader;

        INSERT INTO PR_FormulaDetail (
            FormulaHeader, line, company, Tipo, Operador, Concept, grupo, valor,
            XLastUser, XLastDate, parameter, process, PeriodoINI, PeriodoFin,
            NumberINI, NumberFIN, TipoLiq, ConceptList, Divisor,
            ScriptSource, CompiledExpr
        )
        SELECT
            @formulaheader,
            ISNULL(NULLIF(x.value('(line)[1]', 'int'), 0), ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
            @company,
            NULLIF(LTRIM(RTRIM(x.value('(tipo)[1]', 'char(1)'))), ''),
            NULLIF(LTRIM(RTRIM(x.value('(operador)[1]', 'char(1)'))), ''),
            NULLIF(LTRIM(RTRIM(x.value('(concept)[1]', 'varchar(20)'))), ''),
            NULLIF(LTRIM(RTRIM(x.value('(grupo)[1]', 'char(1)'))), ''),
            NULLIF(x.value('(valor)[1]', 'decimal(18,4)'), 0),
            @xlastuser,
            GETDATE(),
            NULLIF(LTRIM(RTRIM(x.value('(parameter)[1]', 'varchar(20)'))), ''),
            NULLIF(LTRIM(RTRIM(x.value('(process)[1]', 'varchar(20)'))), ''),
            NULLIF(LTRIM(RTRIM(x.value('(periodoini)[1]', 'varchar(20)'))), ''),
            NULLIF(LTRIM(RTRIM(x.value('(periodofin)[1]', 'varchar(20)'))), ''),
            NULLIF(x.value('(numberini)[1]', 'decimal(18,0)'), 0),
            NULLIF(x.value('(numberfin)[1]', 'decimal(18,0)'), 0),
            NULLIF(LTRIM(RTRIM(x.value('(tipoliq)[1]', 'char(1)'))), ''),
            NULLIF(LTRIM(RTRIM(x.value('(conceptlist)[1]', 'varchar(500)'))), ''),
            NULLIF(x.value('(divisor)[1]', 'decimal(18,4)'), 0),
            NULLIF(x.value('(scriptsource)[1]', 'nvarchar(max)'), ''),
            NULLIF(x.value('(compiledexpr)[1]', 'nvarchar(max)'), '')
        FROM @xml.nodes('/root/l') AS T(x);

        COMMIT TRANSACTION;

        SELECT
            @formulaheader AS formulaheader,
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
