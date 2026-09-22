/*
    Elimina líneas de detalle de la misma fórmula en TODAS las demás empresas
    (misma FormulaCode + planilla ShortName + proceso ShortName).

    Cada <l> del XML describe una línea eliminada en origen, con códigos
    portables (FormulaCode / shortname) ya resueltos por la API.

    Usado por: POST /api/formulas/eliminar-lineas-todas-cias
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_lineas_detalle_formula_todas_cias_web]
    @cia            VARCHAR(4),
    @formulaheader  VARCHAR(20),
    @lineas_xml     NVARCHAR(MAX),
    @xlastuser      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @formulaheader = LTRIM(RTRIM(ISNULL(@formulaheader, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = '' OR @formulaheader = ''
    BEGIN
        RAISERROR('Indique compania y formula.', 16, 1);
        RETURN;
    END;

    IF @lineas_xml IS NULL OR LTRIM(RTRIM(@lineas_xml)) = ''
    BEGIN
        RAISERROR('No hay lineas a eliminar en otras empresas.', 16, 1);
        RETURN;
    END;

    DECLARE @xml XML = TRY_CAST(@lineas_xml AS XML);
    IF @xml IS NULL
    BEGIN
        RAISERROR('XML de lineas invalido.', 16, 1);
        RETURN;
    END;

    DECLARE
        @formulacode VARCHAR(50) = NULL,
        @planilla    VARCHAR(50) = NULL,
        @proceso     VARCHAR(50) = NULL;

    SELECT
        @planilla = LTRIM(RTRIM(ISNULL(prt.ShortName, ''))),
        @proceso  = LTRIM(RTRIM(ISNULL(pt.ShortName, '')))
    FROM PR_FormulaHeader fh (NOLOCK)
        INNER JOIN PR_PayRollType prt (NOLOCK)
            ON fh.Payrolltype = prt.PayRollType
        INNER JOIN PR_ProcessType pt (NOLOCK)
            ON fh.Proccestype = pt.ProcessType
    WHERE fh.Company = @cia
      AND fh.FormulaHeader = @formulaheader;

    SELECT @formulacode = LTRIM(RTRIM(ISNULL(c.FormulaCode, '')))
    FROM PR_FormulaHeader fh (NOLOCK)
        INNER JOIN PR_Concept c (NOLOCK)
            ON fh.Concept = c.Concept
           AND fh.Company = c.Company
    WHERE fh.Company = @cia
      AND fh.FormulaHeader = @formulaheader;

    IF @formulacode IS NULL OR @formulacode = ''
    BEGIN
        SELECT @formulacode = LTRIM(RTRIM(ISNULL(fh.formulacode, '')))
        FROM PR_FormulaHeader fh (NOLOCK)
        WHERE fh.Company = @cia
          AND fh.FormulaHeader = @formulaheader;
    END;

    SET @formulacode = NULLIF(LTRIM(RTRIM(@formulacode)), '');
    SET @planilla = NULLIF(@planilla, '');
    SET @proceso = NULLIF(@proceso, '');

    IF @formulacode IS NULL OR @planilla IS NULL OR @proceso IS NULL
    BEGIN
        RAISERROR('No se pudo resolver FormulaCode / planilla / proceso de la formula origen.', 16, 1);
        RETURN;
    END;

    DECLARE @lineas TABLE (
        idx            INT IDENTITY(1, 1) PRIMARY KEY,
        tipo           CHAR(1) NULL,
        operador       CHAR(1) NULL,
        formulacode    VARCHAR(50) NULL,
        grupo          CHAR(1) NULL,
        valor          DECIMAL(18, 6) NULL,
        param_short    VARCHAR(50) NULL,
        proc_short     VARCHAR(50) NULL,
        periodoini     VARCHAR(20) NULL,
        periodofin     VARCHAR(20) NULL,
        numberini      DECIMAL(18, 6) NULL,
        numberfin      DECIMAL(18, 6) NULL,
        tipoliq        CHAR(1) NULL,
        divisor        DECIMAL(18, 6) NULL,
        scriptsource   NVARCHAR(MAX) NULL
    );

    INSERT INTO @lineas (
        tipo, operador, formulacode, grupo, valor,
        param_short, proc_short, periodoini, periodofin,
        numberini, numberfin, tipoliq, divisor, scriptsource
    )
    SELECT
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(tipo)[1]', 'varchar(5)')))), ''),
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(operador)[1]', 'varchar(5)')))), ''),
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(formulacode)[1]', 'varchar(50)')))), ''),
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(grupo)[1]', 'varchar(5)')))), ''),
        CASE
            WHEN NULLIF(LTRIM(RTRIM(x.value('(valor)[1]', 'varchar(40)'))), '') IS NULL THEN NULL
            WHEN ISNUMERIC(NULLIF(LTRIM(RTRIM(x.value('(valor)[1]', 'varchar(40)'))), '')) = 1
                THEN CONVERT(DECIMAL(18, 6), LTRIM(RTRIM(x.value('(valor)[1]', 'varchar(40)'))))
            ELSE NULL
        END,
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(param_short)[1]', 'varchar(50)')))), ''),
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(proc_short)[1]', 'varchar(50)')))), ''),
        NULLIF(LTRIM(RTRIM(x.value('(periodoini)[1]', 'varchar(20)'))), ''),
        NULLIF(LTRIM(RTRIM(x.value('(periodofin)[1]', 'varchar(20)'))), ''),
        CASE
            WHEN NULLIF(LTRIM(RTRIM(x.value('(numberini)[1]', 'varchar(40)'))), '') IS NULL THEN NULL
            WHEN ISNUMERIC(NULLIF(LTRIM(RTRIM(x.value('(numberini)[1]', 'varchar(40)'))), '')) = 1
                THEN CONVERT(DECIMAL(18, 6), LTRIM(RTRIM(x.value('(numberini)[1]', 'varchar(40)'))))
            ELSE NULL
        END,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(x.value('(numberfin)[1]', 'varchar(40)'))), '') IS NULL THEN NULL
            WHEN ISNUMERIC(NULLIF(LTRIM(RTRIM(x.value('(numberfin)[1]', 'varchar(40)'))), '')) = 1
                THEN CONVERT(DECIMAL(18, 6), LTRIM(RTRIM(x.value('(numberfin)[1]', 'varchar(40)'))))
            ELSE NULL
        END,
        NULLIF(UPPER(LTRIM(RTRIM(x.value('(tipoliq)[1]', 'varchar(5)')))), ''),
        CASE
            WHEN NULLIF(LTRIM(RTRIM(x.value('(divisor)[1]', 'varchar(40)'))), '') IS NULL THEN NULL
            WHEN ISNUMERIC(NULLIF(LTRIM(RTRIM(x.value('(divisor)[1]', 'varchar(40)'))), '')) = 1
                THEN CONVERT(DECIMAL(18, 6), LTRIM(RTRIM(x.value('(divisor)[1]', 'varchar(40)'))))
            ELSE NULL
        END,
        NULLIF(LTRIM(RTRIM(x.value('(scriptsource)[1]', 'nvarchar(max)'))), '')
    FROM @xml.nodes('/root/l') AS T(x);

    IF NOT EXISTS (SELECT 1 FROM @lineas)
    BEGIN
        RAISERROR('No hay lineas a eliminar en otras empresas.', 16, 1);
        RETURN;
    END;

    DECLARE
        @company       VARCHAR(4),
        @fh_dest       VARCHAR(20),
        @idx           INT,
        @tipo          CHAR(1),
        @operador      CHAR(1),
        @fc_lin        VARCHAR(50),
        @grupo         CHAR(1),
        @valor         DECIMAL(18, 6),
        @param_short   VARCHAR(50),
        @proc_short    VARCHAR(50),
        @periodoini    VARCHAR(20),
        @periodofin    VARCHAR(20),
        @numberini     DECIMAL(18, 6),
        @numberfin     DECIMAL(18, 6),
        @tipoliq       CHAR(1),
        @divisor       DECIMAL(18, 6),
        @scriptsource  NVARCHAR(MAX),
        @line_del      INT,
        @empresas_ok   INT = 0,
        @lineas_ok     INT = 0;

    DECLARE empresas CURSOR LOCAL FAST_FORWARD FOR
        SELECT Company
        FROM SY_Company (NOLOCK)
        WHERE Company <> @cia
          AND ISNULL(status, 'A') = 'A';

    OPEN empresas;
    FETCH NEXT FROM empresas INTO @company;

    BEGIN TRY
        BEGIN TRANSACTION;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @fh_dest = NULL;

            SELECT TOP 1 @fh_dest = fh.FormulaHeader
            FROM PR_FormulaHeader fh (NOLOCK)
                INNER JOIN PR_Concept c_dest (NOLOCK)
                    ON fh.Concept = c_dest.Concept
                   AND fh.Company = c_dest.Company
                   AND LTRIM(RTRIM(ISNULL(c_dest.FormulaCode, ''))) = @formulacode
                INNER JOIN PR_PayRollType prt (NOLOCK)
                    ON prt.Company = @company
                   AND prt.PayRollType = fh.Payrolltype
                   AND LTRIM(RTRIM(ISNULL(prt.ShortName, ''))) = @planilla
                INNER JOIN PR_ProcessType pt (NOLOCK)
                    ON pt.Company = @company
                   AND pt.ProcessType = fh.Proccestype
                   AND LTRIM(RTRIM(ISNULL(pt.ShortName, ''))) = @proceso
            WHERE fh.Company = @company
            ORDER BY fh.FormulaHeader;

            IF @fh_dest IS NOT NULL AND @fh_dest <> ''
            BEGIN
                DECLARE @hubo BIT = 0;
                SET @idx = 1;

                WHILE @idx <= (SELECT COUNT(*) FROM @lineas)
                BEGIN
                    SELECT
                        @tipo = tipo,
                        @operador = operador,
                        @fc_lin = formulacode,
                        @grupo = grupo,
                        @valor = valor,
                        @param_short = param_short,
                        @proc_short = proc_short,
                        @periodoini = periodoini,
                        @periodofin = periodofin,
                        @numberini = numberini,
                        @numberfin = numberfin,
                        @tipoliq = tipoliq,
                        @divisor = divisor,
                        @scriptsource = scriptsource
                    FROM @lineas
                    WHERE idx = @idx;

                    SET @line_del = NULL;

                    SELECT TOP 1 @line_del = fd.line
                    FROM PR_FormulaDetail fd (NOLOCK)
                        LEFT JOIN PR_Concept c (NOLOCK)
                            ON c.Company = @company
                           AND c.Concept = fd.Concept
                        LEFT JOIN PR_Parameter p (NOLOCK)
                            ON p.Company = @company
                           AND p.Parameter = fd.parameter
                        LEFT JOIN PR_ProcessType pt2 (NOLOCK)
                            ON pt2.Company = @company
                           AND pt2.ProcessType = fd.process
                    WHERE fd.FormulaHeader = @fh_dest
                      AND ISNULL(UPPER(LTRIM(RTRIM(fd.Tipo))), '') = ISNULL(@tipo, '')
                      AND ISNULL(UPPER(LTRIM(RTRIM(fd.Operador))), '') = ISNULL(@operador, '')
                      AND ISNULL(UPPER(LTRIM(RTRIM(fd.grupo))), '') = ISNULL(@grupo, '')
                      AND (
                            (@fc_lin IS NULL AND NULLIF(LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))), '') IS NULL)
                            OR UPPER(LTRIM(RTRIM(ISNULL(c.FormulaCode, '')))) = @fc_lin
                      )
                      AND (
                            (@valor IS NULL AND fd.valor IS NULL)
                            OR (fd.valor IS NOT NULL AND @valor IS NOT NULL AND fd.valor = @valor)
                      )
                      AND (
                            (@param_short IS NULL AND NULLIF(UPPER(LTRIM(RTRIM(ISNULL(p.ShortName, '')))), '') IS NULL)
                            OR UPPER(LTRIM(RTRIM(ISNULL(p.ShortName, '')))) = @param_short
                      )
                      AND (
                            (@proc_short IS NULL AND NULLIF(UPPER(LTRIM(RTRIM(ISNULL(pt2.ShortName, '')))), '') IS NULL)
                            OR UPPER(LTRIM(RTRIM(ISNULL(pt2.ShortName, '')))) = @proc_short
                      )
                      AND ISNULL(LTRIM(RTRIM(ISNULL(fd.PeriodoINI, ''))), '') = ISNULL(@periodoini, '')
                      AND ISNULL(LTRIM(RTRIM(ISNULL(fd.PeriodoFin, ''))), '') = ISNULL(@periodofin, '')
                      AND (
                            (@numberini IS NULL AND fd.NumberINI IS NULL)
                            OR (fd.NumberINI IS NOT NULL AND @numberini IS NOT NULL AND fd.NumberINI = @numberini)
                      )
                      AND (
                            (@numberfin IS NULL AND fd.NumberFIN IS NULL)
                            OR (fd.NumberFIN IS NOT NULL AND @numberfin IS NOT NULL AND fd.NumberFIN = @numberfin)
                      )
                      AND ISNULL(UPPER(LTRIM(RTRIM(ISNULL(fd.TipoLiq, '')))), '') = ISNULL(@tipoliq, '')
                      AND (
                            (@divisor IS NULL AND fd.Divisor IS NULL)
                            OR (fd.Divisor IS NOT NULL AND @divisor IS NOT NULL AND fd.Divisor = @divisor)
                      )
                      AND (
                            ISNULL(@tipo, '') <> 'K'
                            OR ISNULL(LTRIM(RTRIM(ISNULL(fd.ScriptSource, ''))), '')
                               = ISNULL(@scriptsource, '')
                      )
                    ORDER BY fd.line;

                    IF @line_del IS NOT NULL
                    BEGIN
                        DELETE FROM PR_FormulaDetail
                        WHERE FormulaHeader = @fh_dest
                          AND line = @line_del;

                        SET @lineas_ok = @lineas_ok + 1;
                        SET @hubo = 1;
                    END;

                    SET @idx = @idx + 1;
                END;

                IF @hubo = 1
                BEGIN
                    /* Renumera lineas sin colisionar PK (FormulaHeader, line). */
                    UPDATE PR_FormulaDetail
                    SET line = line + 100000
                    WHERE FormulaHeader = @fh_dest;

                    ;WITH ord AS (
                        SELECT
                            FormulaHeader,
                            line,
                            ROW_NUMBER() OVER (ORDER BY line) AS new_line
                        FROM PR_FormulaDetail
                        WHERE FormulaHeader = @fh_dest
                    )
                    UPDATE fd
                    SET fd.line = ord.new_line,
                        fd.XLastUser = ISNULL(@xlastuser, fd.XLastUser),
                        fd.XLastDate = GETDATE()
                    FROM PR_FormulaDetail fd
                        INNER JOIN ord
                            ON ord.FormulaHeader = fd.FormulaHeader
                           AND ord.line = fd.line;

                    UPDATE PR_FormulaHeader
                    SET XLastUser = ISNULL(@xlastuser, XLastUser),
                        XLastDate = GETDATE()
                    WHERE FormulaHeader = @fh_dest
                      AND Company = @company;

                    SET @empresas_ok = @empresas_ok + 1;
                END;
            END;

            FETCH NEXT FROM empresas INTO @company;
        END;

        CLOSE empresas;
        DEALLOCATE empresas;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF CURSOR_STATUS('local', 'empresas') >= 0
        BEGIN
            CLOSE empresas;
            DEALLOCATE empresas;
        END;
        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('%s', 16, 1, @err);
        RETURN;
    END CATCH;

    SELECT
        @empresas_ok AS empresas_afectadas,
        @lineas_ok AS lineas_eliminadas,
        CASE
            WHEN @empresas_ok = 0 THEN
                'No se encontro la misma formula (o las mismas lineas) en otras empresas.'
            WHEN @empresas_ok = 1 THEN
                'Se elimino la(s) linea(s) en 1 empresa adicional.'
            ELSE
                'Se elimino la(s) linea(s) en ' + CONVERT(VARCHAR(10), @empresas_ok) + ' empresas adicionales.'
        END AS mensaje;
END
GO
