/*
    Lista los FormulaCode (nemónicos) escritos EN DURO en llamadas a
    sp_pr_registrar_concepto dentro de un SP de cálculo.

    - Ignora comentarios de línea (--) y de bloque (/* */).
    - Solo incluye literales 'NEMONICO' / N'NEMONICO' (no @nemonico ni variables).
    - El 8º argumento posicional de sp_pr_registrar_concepto es el FormulaCode.

    Ejemplo:
      EXEC sp_pr_listar_nemonicos_registrar_concepto_web
           @sp_name = 'sp_pr_calcular_finmes_persona';
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_listar_nemonicos_registrar_concepto_web
    @sp_name sysname
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @name sysname = LTRIM(RTRIM(ISNULL(@sp_name, '')));
    IF @name = ''
    BEGIN
        RAISERROR('Indique el nombre del SP de cálculo (@sp_name).', 16, 1);
        RETURN;
    END;

    DECLARE @simple sysname = PARSENAME(@name, 1);
    IF @simple IS NULL SET @simple = @name;

    DECLARE @oid int = OBJECT_ID(N'dbo.' + @simple);
    IF @oid IS NULL
        SET @oid = OBJECT_ID(@name);
    IF @oid IS NULL
    BEGIN
        RAISERROR('No existe el procedimiento %s en esta base.', 16, 1, @name);
        RETURN;
    END;

    DECLARE @src nvarchar(max) = OBJECT_DEFINITION(@oid);
    IF @src IS NULL
    BEGIN
        RAISERROR('No se pudo leer la definición de %s (¿encriptado?).', 16, 1, @name);
        RETURN;
    END;

    /* --- Quitar comentarios respetando literales '...' --- */
    DECLARE @clean nvarchar(max) = N'';
    DECLARE @i int = 1;
    DECLARE @n int = LEN(@src);
    DECLARE @ch nchar(1);
    DECLARE @ch2 nchar(1);

    WHILE @i <= @n
    BEGIN
        SET @ch = SUBSTRING(@src, @i, 1);
        SET @ch2 = CASE WHEN @i < @n THEN SUBSTRING(@src, @i + 1, 1) ELSE N'' END;

        IF @ch = N''''
        BEGIN
            SET @clean += @ch;
            SET @i += 1;
            WHILE @i <= @n
            BEGIN
                SET @ch = SUBSTRING(@src, @i, 1);
                SET @clean += @ch;
                IF @ch = N''''
                BEGIN
                    IF @i < @n AND SUBSTRING(@src, @i + 1, 1) = N''''
                    BEGIN
                        SET @clean += N'''';
                        SET @i += 2;
                        CONTINUE;
                    END
                    SET @i += 1;
                    BREAK;
                END
                SET @i += 1;
            END
            CONTINUE;
        END

        IF @ch = N'/' AND @ch2 = N'*'
        BEGIN
            SET @i += 2;
            WHILE @i < @n AND NOT (
                SUBSTRING(@src, @i, 1) = N'*' AND SUBSTRING(@src, @i + 1, 1) = N'/'
            )
                SET @i += 1;
            SET @i += 2;
            SET @clean += N' ';
            CONTINUE;
        END

        IF @ch = N'-' AND @ch2 = N'-'
        BEGIN
            WHILE @i <= @n AND SUBSTRING(@src, @i, 1) NOT IN (NCHAR(13), NCHAR(10))
                SET @i += 1;
            CONTINUE;
        END

        SET @clean += @ch;
        SET @i += 1;
    END

    DECLARE @upper nvarchar(max) = UPPER(@clean);
    DECLARE @needle nvarchar(100) = N'SP_PR_REGISTRAR_CONCEPTO';
    DECLARE @pos int = 1;
    DECLARE @hit int;
    DECLARE @start int;
    DECLARE @args nvarchar(max);
    DECLARE @p int;
    DECLARE @arg_n int;
    DECLARE @in_str bit;
    DECLARE @c nchar(1);
    DECLARE @arg nvarchar(400);
    DECLARE @nemonico varchar(255);
    DECLARE @back nvarchar(80);
    DECLARE @b0 int;
    DECLARE @alen int;
    DECLARE @look nvarchar(20);

    CREATE TABLE #nemos (
        ord int IDENTITY(1, 1) NOT NULL,
        formulacode varchar(255) NOT NULL,
        formulacode_u varchar(255) NOT NULL
    );

    WHILE 1 = 1
    BEGIN
        SET @hit = CHARINDEX(@needle, @upper, @pos);
        IF @hit = 0 BREAK;

        SET @start = @hit;
        WHILE @start > 1 AND SUBSTRING(@upper, @start - 1, 1) NOT IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13), N'.')
            SET @start -= 1;
        IF @start > 4 AND SUBSTRING(@upper, @start - 4, 4) = N'DBO.'
            SET @start -= 4;

        SET @b0 = CASE WHEN @start > 40 THEN @start - 40 ELSE 1 END;
        SET @back = SUBSTRING(@upper, @b0, @start - @b0);
        IF @back NOT LIKE N'%EXEC%'
        BEGIN
            SET @pos = @hit + LEN(@needle);
            CONTINUE;
        END

        SET @i = @hit + LEN(@needle);
        WHILE @i <= LEN(@clean) AND SUBSTRING(@clean, @i, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13))
            SET @i += 1;

        SET @args = N'';
        SET @in_str = 0;
        WHILE @i <= LEN(@clean)
        BEGIN
            SET @c = SUBSTRING(@clean, @i, 1);
            IF @c = N''''
            BEGIN
                SET @args += @c;
                IF @in_str = 1 AND @i < LEN(@clean) AND SUBSTRING(@clean, @i + 1, 1) = N''''
                BEGIN
                    SET @args += N'''';
                    SET @i += 2;
                    CONTINUE;
                END
                SET @in_str = CASE WHEN @in_str = 1 THEN 0 ELSE 1 END;
                SET @i += 1;
                CONTINUE;
            END
            IF @in_str = 0 AND @c = N';'
                BREAK;

            IF @in_str = 0
            BEGIN
                SET @look = UPPER(SUBSTRING(@clean, @i, 8));
                IF @look LIKE N'EXECUTE %'
                   OR @look LIKE N'EXEC %'
                   OR @look LIKE N'SET %'
                   OR @look LIKE N'IF %'
                   OR @look LIKE N'BEGIN%'
                   OR @look LIKE N'END%'
                    BREAK;
            END

            SET @args += @c;
            SET @i += 1;
            IF LEN(@args) > 4000 BREAK;
        END

        /* Partir argumentos posicionales; el 8º es FormulaCode */
        SET @arg_n = 1;
        SET @arg = N'';
        SET @in_str = 0;
        SET @p = 1;
        SET @alen = LEN(@args);
        SET @nemonico = NULL;

        WHILE @p <= @alen
        BEGIN
            SET @c = SUBSTRING(@args, @p, 1);
            IF @c = N''''
            BEGIN
                SET @arg += @c;
                IF @in_str = 1 AND @p < @alen AND SUBSTRING(@args, @p + 1, 1) = N''''
                BEGIN
                    SET @arg += N'''';
                    SET @p += 2;
                    CONTINUE;
                END
                SET @in_str = CASE WHEN @in_str = 1 THEN 0 ELSE 1 END;
                SET @p += 1;
                CONTINUE;
            END

            IF @in_str = 0 AND @c = N','
            BEGIN
                IF @arg_n = 8
                    BREAK;
                SET @arg_n += 1;
                SET @arg = N'';
                SET @p += 1;
                CONTINUE;
            END

            IF @arg_n = 8
                SET @arg += @c;
            SET @p += 1;
        END

        IF @arg_n = 8
        BEGIN
            SET @arg = LTRIM(RTRIM(@arg));
            IF LEFT(@arg, 2) = N'N''' AND RIGHT(@arg, 1) = N'''' AND LEN(@arg) >= 3
                SET @nemonico = SUBSTRING(@arg, 3, LEN(@arg) - 3);
            ELSE IF LEFT(@arg, 1) = N'''' AND RIGHT(@arg, 1) = N'''' AND LEN(@arg) >= 2
                SET @nemonico = SUBSTRING(@arg, 2, LEN(@arg) - 2);
            ELSE
                SET @nemonico = NULL;

            IF @nemonico IS NOT NULL AND LTRIM(RTRIM(@nemonico)) <> ''
            BEGIN
                SET @nemonico = LTRIM(RTRIM(@nemonico));
                IF NOT EXISTS (
                    SELECT 1 FROM #nemos WHERE formulacode_u = UPPER(@nemonico)
                )
                    INSERT INTO #nemos (formulacode, formulacode_u)
                    VALUES (@nemonico, UPPER(@nemonico));
            END
        END

        SET @pos = @hit + LEN(@needle);
    END

    SELECT
        ROW_NUMBER() OVER (ORDER BY ord) AS nro,
        formulacode AS nemonico,
        @simple AS sp_name,
        DB_NAME() AS database_name
    FROM #nemos
    ORDER BY ord;
END
GO
