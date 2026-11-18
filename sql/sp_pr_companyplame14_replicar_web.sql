/*
    Replica la configuración PLAME Archivo 14 de @cia_origen a las demás
    compañías activas, mapeando Concept por FormulaCode.

    Solo afecta filas con Plame = '14'. Conserva otras configuraciones PLAME.

    Usado por: POST /api/plame/config-14/replicar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_companyplame14_replicar_web]
    @cia_origen VARCHAR(4),
    @xlastuser  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia_origen = LTRIM(RTRIM(ISNULL(@cia_origen, '')));
    SET @xlastuser = LEFT(NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), ''), 20);
    IF @xlastuser IS NULL SET @xlastuser = 'web';

    IF @cia_origen = ''
    BEGIN
        RAISERROR('Indique la compañía origen.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.PR_CompanyPlame (NOLOCK)
        WHERE Company = @cia_origen
          AND LTRIM(RTRIM(ISNULL(Plame, ''))) = '14'
    )
    BEGIN
        RAISERROR('La compañía origen no tiene configuración PLAME 14.', 16, 1);
        RETURN;
    END;

    DECLARE @src TABLE (
        line         INT NOT NULL,
        typ          VARCHAR(2) NOT NULL,
        concept      VARCHAR(20) NOT NULL,
        applysum     CHAR(1) NOT NULL,
        formulacode  VARCHAR(40) NOT NULL,
        description  NVARCHAR(120) NULL
    );

    INSERT INTO @src (line, typ, concept, applysum, formulacode, description)
    SELECT
        p.line,
        UPPER(LTRIM(RTRIM(ISNULL(p.Type, '')))),
        p.Concept,
        UPPER(LEFT(LTRIM(RTRIM(ISNULL(p.ApplySum, 'P'))), 1)),
        LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))),
        CAST(ISNULL(c.Description, '') AS NVARCHAR(120))
    FROM dbo.PR_CompanyPlame p (NOLOCK)
    LEFT JOIN dbo.PR_Concept c (NOLOCK)
        ON c.Company = p.Company
       AND c.Concept = p.Concept
    WHERE p.Company = @cia_origen
      AND LTRIM(RTRIM(ISNULL(p.Plame, ''))) = '14';

    IF EXISTS (SELECT 1 FROM @src WHERE formulacode = '')
    BEGIN
        RAISERROR('Hay conceptos origen sin FormulaCode; no se puede mapear a otras empresas.', 16, 1);
        RETURN;
    END;

    DECLARE @destinos TABLE (company VARCHAR(4) NOT NULL PRIMARY KEY);
    INSERT INTO @destinos (company)
    SELECT LTRIM(RTRIM(Company))
    FROM dbo.SY_Company (NOLOCK)
    WHERE ISNULL(status, 'A') = 'A'
      AND LTRIM(RTRIM(Company)) <> @cia_origen;

    DECLARE @result TABLE (
        company     VARCHAR(4) NOT NULL,
        ok          BIT NOT NULL,
        insertados  INT NOT NULL,
        omitidos    INT NOT NULL,
        mensaje     NVARCHAR(400) NULL
    );

    DECLARE @dst VARCHAR(4);
    DECLARE @ins INT;
    DECLARE @omit INT;
    DECLARE @msg NVARCHAR(400);
    DECLARE @ok BIT;

    DECLARE dest_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT company FROM @destinos ORDER BY company;

    OPEN dest_cur;
    FETCH NEXT FROM dest_cur INTO @dst;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ins = 0;
        SET @omit = 0;
        SET @msg = NULL;
        SET @ok = 1;

        BEGIN TRY
            BEGIN TRAN;

            DELETE FROM dbo.PR_CompanyPlame
            WHERE Company = @dst
              AND LTRIM(RTRIM(ISNULL(Plame, ''))) = '14';

            INSERT INTO dbo.PR_CompanyPlame
                (Company, line, Plame, Concept, Type, ApplySum, XLastUser, XLastDate)
            SELECT
                @dst,
                s.line,
                '14',
                dstc.Concept,
                s.typ,
                s.applysum,
                @xlastuser,
                GETDATE()
            FROM @src s
            CROSS APPLY (
                SELECT TOP 1 c.Concept
                FROM dbo.PR_Concept c (NOLOCK)
                WHERE c.Company = @dst
                  AND LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) = s.formulacode
                ORDER BY c.Concept
            ) dstc;

            SET @ins = @@ROWCOUNT;
            SET @omit = (SELECT COUNT(*) FROM @src) - @ins;

            IF @omit > 0
                SET @msg = N'Replicado con ' + CAST(@omit AS NVARCHAR(10))
                         + N' concepto(s) sin mapeo por FormulaCode.';
            ELSE
                SET @msg = N'Replicado correctamente.';

            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN;
            SET @ok = 0;
            SET @ins = 0;
            SET @omit = (SELECT COUNT(*) FROM @src);
            SET @msg = ERROR_MESSAGE();
        END CATCH;

        INSERT INTO @result (company, ok, insertados, omitidos, mensaje)
        VALUES (@dst, @ok, @ins, @omit, @msg);

        FETCH NEXT FROM dest_cur INTO @dst;
    END;

    CLOSE dest_cur;
    DEALLOCATE dest_cur;

    SELECT
        company,
        ok,
        insertados,
        omitidos,
        mensaje
    FROM @result
    ORDER BY company;

    SELECT
        CAST(1 AS BIT) AS ok,
        (SELECT COUNT(*) FROM @result WHERE ok = 1) AS empresas_ok,
        (SELECT COUNT(*) FROM @result WHERE ok = 0) AS empresas_error,
        (SELECT COUNT(*) FROM @result) AS empresas_total,
        N'Replicación PLAME 14 finalizada.' AS mensaje;
END
GO
