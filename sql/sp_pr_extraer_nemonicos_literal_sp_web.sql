/*
    Extrae nemónicos literales del texto de un SP de cálculo (OBJECT_DEFINITION).

    Detecta:
      - sp_pr_registrar_concepto ... @tc, 'NEMONICO'  (sin @nemonico)
      - sp_pr_registrar_log_calculo ... @UserID, 'NEMONICO' (sin @nemonico)
      - FormulaCode = 'NEMONICO' en líneas no comentadas

    Usado por: sp_pr_depurar_conceptos_auxiliares_web
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_extraer_nemonicos_literal_sp_web]
    @procedure_name VARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #codes (
        formulacode VARCHAR(50) NOT NULL PRIMARY KEY,
        origen      VARCHAR(30) NOT NULL
    );

    SET @procedure_name = LTRIM(RTRIM(ISNULL(@procedure_name, '')));

    IF @procedure_name = '' OR OBJECT_ID(@procedure_name) IS NULL
    BEGIN
        SELECT
            CAST('' AS VARCHAR(50)) AS formulacode,
            CAST('' AS VARCHAR(30)) AS origen
        WHERE 1 = 0;
        RETURN;
    END;

    DECLARE @sp_def   NVARCHAR(MAX);
    DECLARE @pos      INT = 1;
    DECLARE @def_len  INT;
    DECLARE @line_start INT = 1;
    DECLARE @line     NVARCHAR(MAX);
    DECLARE @ch       NCHAR(1);
    DECLARE @code     VARCHAR(50);
    DECLARE @q1       INT;
    DECLARE @q2       INT;
    DECLARE @anchor   INT;
    DECLARE @fc_pos   INT;
    DECLARE @eq_pos   INT;

    SELECT @sp_def = OBJECT_DEFINITION(OBJECT_ID(@procedure_name));

    IF @sp_def IS NULL OR LEN(@sp_def) = 0
    BEGIN
        SELECT formulacode, origen FROM #codes;
        RETURN;
    END;

    SET @def_len = LEN(@sp_def);

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
            BEGIN
                IF @line LIKE '%sp_pr_registrar_concepto%'
                   AND @line NOT LIKE '%@nemonico%'
                BEGIN
                    SET @anchor = CHARINDEX('@tc', @line);
                    IF @anchor > 0
                    BEGIN
                        SET @q1 = CHARINDEX('''', @line, @anchor);
                        IF @q1 > 0
                        BEGIN
                            SET @q2 = CHARINDEX('''', @line, @q1 + 1);
                            IF @q2 > @q1 + 1
                            BEGIN
                                SET @code = UPPER(LTRIM(RTRIM(SUBSTRING(@line, @q1 + 1, @q2 - @q1 - 1))));
                                IF @code <> '' AND @code NOT LIKE '%@%'
                                   AND NOT EXISTS (SELECT 1 FROM #codes WHERE formulacode = @code)
                                    INSERT INTO #codes VALUES (@code, 'registrar_concepto');
                            END;
                        END;
                    END;
                END;

                IF @line LIKE '%sp_pr_registrar_log_calculo%'
                   AND @line NOT LIKE '%@nemonico%'
                BEGIN
                    SET @anchor = CHARINDEX('@UserID', @line);
                    IF @anchor = 0 SET @anchor = CHARINDEX('@userid', @line);
                    IF @anchor > 0
                    BEGIN
                        SET @q1 = CHARINDEX('''', @line, @anchor);
                        IF @q1 > 0
                        BEGIN
                            SET @q2 = CHARINDEX('''', @line, @q1 + 1);
                            IF @q2 > @q1 + 1
                            BEGIN
                                SET @code = UPPER(LTRIM(RTRIM(SUBSTRING(@line, @q1 + 1, @q2 - @q1 - 1))));
                                IF @code <> '' AND @code NOT LIKE '%@%'
                                   AND NOT EXISTS (SELECT 1 FROM #codes WHERE formulacode = @code)
                                    INSERT INTO #codes VALUES (@code, 'registrar_log');
                            END;
                        END;
                    END;
                END;

                SET @fc_pos = CHARINDEX('FormulaCode', @line);
                IF @fc_pos > 0
                BEGIN
                    SET @eq_pos = CHARINDEX('=', @line, @fc_pos);
                    IF @eq_pos > 0
                    BEGIN
                        SET @q1 = CHARINDEX('''', @line, @eq_pos);
                        IF @q1 > 0
                        BEGIN
                            SET @q2 = CHARINDEX('''', @line, @q1 + 1);
                            IF @q2 > @q1 + 1
                            BEGIN
                                SET @code = UPPER(LTRIM(RTRIM(SUBSTRING(@line, @q1 + 1, @q2 - @q1 - 1))));
                                IF @code <> '' AND @code NOT LIKE '%@%'
                                   AND NOT EXISTS (SELECT 1 FROM #codes WHERE formulacode = @code)
                                    INSERT INTO #codes VALUES (@code, 'formulacode_eq');
                            END;
                        END;
                    END;
                END;
            END;

            IF @ch = CHAR(13) AND @pos < @def_len AND SUBSTRING(@sp_def, @pos + 1, 1) = CHAR(10)
            BEGIN
                SET @line_start = @pos + 2;
                SET @pos = @pos + 1;
            END
            ELSE
                SET @line_start = @pos + 1;
        END;

        SET @pos = @pos + 1;
    END;

    IF @line_start <= @def_len
    BEGIN
        SET @line = LTRIM(RTRIM(SUBSTRING(@sp_def, @line_start, @def_len - @line_start + 1)));
        IF CHARINDEX('--', @line) > 0
            SET @line = LTRIM(RTRIM(LEFT(@line, CHARINDEX('--', @line) - 1)));

        IF @line <> ''
           AND @line LIKE '%sp_pr_registrar_concepto%'
           AND @line NOT LIKE '%@nemonico%'
        BEGIN
            SET @anchor = CHARINDEX('@tc', @line);
            IF @anchor > 0
            BEGIN
                SET @q1 = CHARINDEX('''', @line, @anchor);
                IF @q1 > 0
                BEGIN
                    SET @q2 = CHARINDEX('''', @line, @q1 + 1);
                    IF @q2 > @q1 + 1
                    BEGIN
                        SET @code = UPPER(LTRIM(RTRIM(SUBSTRING(@line, @q1 + 1, @q2 - @q1 - 1))));
                        IF @code <> '' AND @code NOT LIKE '%@%'
                           AND NOT EXISTS (SELECT 1 FROM #codes WHERE formulacode = @code)
                            INSERT INTO #codes VALUES (@code, 'registrar_concepto');
                    END;
                END;
            END;
        END;
    END;

    SELECT formulacode, origen
    FROM #codes
    ORDER BY formulacode;
END
GO
