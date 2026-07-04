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

        IF @detalle_xml IS NOT NULL AND LTRIM(RTRIM(@detalle_xml)) <> ''
        BEGIN
            DECLARE @xml XML = TRY_CAST(@detalle_xml AS XML);
            IF @xml IS NOT NULL
            BEGIN
                INSERT INTO PR_FormulaDetail (
                    FormulaHeader, line, company, Tipo, Operador, Concept, grupo, valor,
                    XLastUser, XLastDate, parameter, process, PeriodoINI, PeriodoFin,
                    NumberINI, NumberFIN, TipoLiq, ConceptList, Divisor
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
                    NULLIF(x.value('(divisor)[1]', 'decimal(18,4)'), 0)
                FROM @xml.nodes('/root/l') AS T(x);
            END;
        END;

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
