/*
    Validaciones previas al cálculo de planilla (módulo Procesar planilla).

    Detecta conceptos configurados en más de una vía para FIN_DE_MES:
      M — Maestro de conceptos: Insertar en = Mensual (flaginsertar = 'M')
      S — Procedimiento de cálculo: llamadas literales a sp_pr_registrar_concepto
      F — Fórmulas del proceso (PR_FormulaHeader)

    Solo una vía debe estar activa por concepto.

    Usado por: POST /api/procesar-planilla/validar-pre-calculo
    y antes de /ejecutar_calculo_streaming y /ejecutar_calculo_planilla.

    El procedimiento de cálculo (p. ej. sp_pr_calcular_finmes_persona) se obtiene de
    PR_ProcessType.ProcedureName en la BD del cliente; no se versiona en sql/ porque
    puede variar por empresa.

    Parámetros:
      @cia         — compañía
      @payrolltype — tipo de planilla
      @processtype — proceso
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_validar_pre_calculo_web]
    @cia         VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));

    DECLARE @proceso_shortname VARCHAR(50);
    DECLARE @procedure_name VARCHAR(128);
    DECLARE @sp_def NVARCHAR(MAX);

    SELECT
        @proceso_shortname = LTRIM(RTRIM(ISNULL(PT.ShortName, ''))),
        @procedure_name = LTRIM(RTRIM(ISNULL(PT.ProcedureName, '')))
    FROM PR_ProcessType PT (NOLOCK)
    WHERE PT.Company = @cia
      AND PT.ProcessType = @processtype;

    CREATE TABLE #errores (
        person      VARCHAR(20) NULL,
        name        VARCHAR(200) NULL,
        observacion VARCHAR(500) NOT NULL
    );

    CREATE TABLE #vias (
        formulacode VARCHAR(50) NOT NULL,
        via         CHAR(1) NOT NULL,
        PRIMARY KEY (formulacode, via)
    );

    CREATE TABLE #sp_nemonicos (
        formulacode VARCHAR(50) NOT NULL PRIMARY KEY
    );

    /* Solo aplica al proceso mensual (FIN_DE_MES). */
    IF @proceso_shortname <> 'FIN_DE_MES'
    BEGIN
        SELECT
            CAST('' AS VARCHAR(20)) AS person,
            CAST('' AS VARCHAR(200)) AS name,
            CAST('' AS VARCHAR(500)) AS observacion
        WHERE 1 = 0;
        RETURN;
    END

    /* M — Insertar en mensual */
    INSERT INTO #vias (formulacode, via)
    SELECT DISTINCT
        UPPER(LTRIM(RTRIM(C.FormulaCode))),
        'M'
    FROM PR_Concept C (NOLOCK)
    WHERE C.Company = @cia
      AND ISNULL(C.flaginsertar, 'N') = 'M'
      AND LTRIM(RTRIM(ISNULL(C.FormulaCode, ''))) <> '';

    /* F — Fórmulas del proceso */
    INSERT INTO #vias (formulacode, via)
    SELECT DISTINCT
        UPPER(LTRIM(RTRIM(C.FormulaCode))),
        'F'
    FROM PR_FormulaHeader FH (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON FH.Concept = C.Concept
           AND C.Company = @cia
    WHERE FH.Company = @cia
      AND FH.Payrolltype = @payrolltype
      AND FH.Proccestype = @processtype
      AND LTRIM(RTRIM(ISNULL(C.FormulaCode, ''))) <> '';

    /* S — Llamadas literales a sp_pr_registrar_concepto en el SP de cálculo */
    IF @procedure_name <> ''
       AND OBJECT_ID(@procedure_name) IS NOT NULL
    BEGIN
        SELECT @sp_def = OBJECT_DEFINITION(OBJECT_ID(@procedure_name));

        IF @sp_def IS NOT NULL AND LEN(@sp_def) > 0
        BEGIN
            DECLARE @pos INT = 1;
            DECLARE @def_len INT = LEN(@sp_def);
            DECLARE @line_start INT = 1;
            DECLARE @line NVARCHAR(MAX);
            DECLARE @ch NCHAR(1);
            DECLARE @tc_pos INT;
            DECLARE @q1 INT;
            DECLARE @q2 INT;
            DECLARE @code VARCHAR(50);

            WHILE @pos <= @def_len
            BEGIN
                SET @ch = SUBSTRING(@sp_def, @pos, 1);

                IF @ch IN (CHAR(10), CHAR(13))
                BEGIN
                    SET @line = SUBSTRING(@sp_def, @line_start, @pos - @line_start);
                    SET @line = LTRIM(RTRIM(@line));

                    IF CHARINDEX('--', @line) > 0
                        SET @line = LTRIM(RTRIM(LEFT(@line, CHARINDEX('--', @line) - 1)));

                    IF @line <> ''
                       AND @line LIKE '%sp_pr_registrar_concepto%'
                       AND @line NOT LIKE '%@nemonico%'
                    BEGIN
                        SET @tc_pos = CHARINDEX('@tc', @line);
                        IF @tc_pos > 0
                        BEGIN
                            SET @q1 = CHARINDEX('''', @line, @tc_pos);
                            IF @q1 > 0
                            BEGIN
                                SET @q2 = CHARINDEX('''', @line, @q1 + 1);
                                IF @q2 > @q1 + 1
                                BEGIN
                                    SET @code = UPPER(LTRIM(RTRIM(SUBSTRING(@line, @q1 + 1, @q2 - @q1 - 1))));
                                    IF @code <> ''
                                       AND @code NOT LIKE '%@%'
                                       AND NOT EXISTS (SELECT 1 FROM #sp_nemonicos S WHERE S.formulacode = @code)
                                    BEGIN
                                        INSERT INTO #sp_nemonicos (formulacode) VALUES (@code);
                                    END
                                END
                            END
                        END
                    END

                    IF @ch = CHAR(13) AND @pos < @def_len AND SUBSTRING(@sp_def, @pos + 1, 1) = CHAR(10)
                    BEGIN
                        SET @line_start = @pos + 2;
                        SET @pos = @pos + 1;
                    END
                    ELSE
                    BEGIN
                        SET @line_start = @pos + 1;
                    END
                END

                SET @pos = @pos + 1;
            END

            /* Última línea si el texto no termina en salto */
            IF @line_start <= @def_len
            BEGIN
                SET @line = LTRIM(RTRIM(SUBSTRING(@sp_def, @line_start, @def_len - @line_start + 1)));

                IF CHARINDEX('--', @line) > 0
                    SET @line = LTRIM(RTRIM(LEFT(@line, CHARINDEX('--', @line) - 1)));

                IF @line <> ''
                   AND @line LIKE '%sp_pr_registrar_concepto%'
                   AND @line NOT LIKE '%@nemonico%'
                BEGIN
                    SET @tc_pos = CHARINDEX('@tc', @line);
                    IF @tc_pos > 0
                    BEGIN
                        SET @q1 = CHARINDEX('''', @line, @tc_pos);
                        IF @q1 > 0
                        BEGIN
                            SET @q2 = CHARINDEX('''', @line, @q1 + 1);
                            IF @q2 > @q1 + 1
                            BEGIN
                                SET @code = UPPER(LTRIM(RTRIM(SUBSTRING(@line, @q1 + 1, @q2 - @q1 - 1))));
                                IF @code <> ''
                                   AND @code NOT LIKE '%@%'
                                   AND NOT EXISTS (SELECT 1 FROM #sp_nemonicos S WHERE S.formulacode = @code)
                                BEGIN
                                    INSERT INTO #sp_nemonicos (formulacode) VALUES (@code);
                                END
                            END
                        END
                    END
                END
            END
        END

        INSERT INTO #vias (formulacode, via)
        SELECT formulacode, 'S'
        FROM #sp_nemonicos;
    END

    INSERT INTO #errores (person, name, observacion)
    SELECT
        NULL,
        NULL,
        D.formulacode
            + CASE WHEN ISNULL(C.Description, '') <> '' THEN ' (' + LTRIM(RTRIM(C.Description)) + ')' ELSE '' END
            + ': configurado en más de una vía ('
            + STUFF((
                SELECT ', ' + CASE V2.via
                    WHEN 'M' THEN 'Insertar en mensual'
                    WHEN 'S' THEN 'Procedimiento de cálculo'
                    WHEN 'F' THEN 'Fórmulas del proceso'
                END
                FROM #vias V2
                WHERE V2.formulacode = D.formulacode
                ORDER BY V2.via
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
            + '). Solo debe estar en una.'
    FROM (
        SELECT formulacode
        FROM #vias
        GROUP BY formulacode
        HAVING COUNT(DISTINCT via) > 1
    ) D
        LEFT JOIN PR_Concept C (NOLOCK)
            ON C.Company = @cia
           AND UPPER(LTRIM(RTRIM(C.FormulaCode))) = D.formulacode;

    SELECT
        LTRIM(RTRIM(ISNULL(person, ''))) AS person,
        LTRIM(RTRIM(ISNULL(name, ''))) AS name,
        LTRIM(RTRIM(observacion)) AS observacion
    FROM #errores
    ORDER BY observacion;
END
GO
