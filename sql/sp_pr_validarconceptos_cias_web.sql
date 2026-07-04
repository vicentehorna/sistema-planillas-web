/*
    Valida conceptos filtrados de una compañía frente a las demás empresas activas:
      - FALTANTE: no existe el nemónico (FormulaCode) en destino
      - DIFERENCIA: existe pero PDT, Insertar en, Afecto 5ta o Afecto AFP no coinciden

    Filtros (mismos criterios que el listado web):
      @company, @descripcion, @tipos (códigos cortos separados por coma)

    Resultados:
      1) total_origen
      2) resumen por empresa destino (faltantes, diferencias)
      3) detalle de incidencias
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_validarconceptos_cias_web]
    @company     VARCHAR(4),
    @descripcion VARCHAR(50) = NULL,
    @tipos       VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @descripcion = NULLIF(LTRIM(RTRIM(ISNULL(@descripcion, ''))), '');
    SET @tipos = NULLIF(LTRIM(RTRIM(ISNULL(@tipos, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía origen.', 16, 1);
        RETURN;
    END

    DECLARE @tipos_filtro TABLE (shortname VARCHAR(10) NOT NULL PRIMARY KEY);

    IF @tipos IS NOT NULL
    BEGIN
        DECLARE @tipos_work VARCHAR(200) = @tipos + ',';
        DECLARE @pos INT;
        DECLARE @piece VARCHAR(10);

        WHILE LEN(@tipos_work) > 0
        BEGIN
            SET @pos = CHARINDEX(',', @tipos_work);
            IF @pos = 0
                BREAK;

            SET @piece = UPPER(LTRIM(RTRIM(LEFT(@tipos_work, @pos - 1))));
            SET @tipos_work = SUBSTRING(@tipos_work, @pos + 1, LEN(@tipos_work));

            IF @piece <> ''
            AND NOT EXISTS (SELECT 1 FROM @tipos_filtro tf WHERE tf.shortname = @piece)
                INSERT INTO @tipos_filtro (shortname) VALUES (@piece);
        END
    END

    SELECT
        LTRIM(RTRIM(C.FormulaCode)) AS formulacode,
        ISNULL(C.Description, '') AS description,
        ISNULL(T.ShortName, '') AS tiposhortname,
        ISNULL(LTRIM(RTRIM(C.pdt)), '') AS pdt,
        ISNULL(UPPER(LTRIM(RTRIM(C.flaginsertar))), 'N') AS flaginsertar,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafecto5ta))), 'N') AS flagafecto5ta,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafectoAFP))), 'N') AS flagafectoafp
    INTO #origen
    FROM PR_Concept C (NOLOCK)
        LEFT JOIN PR_ConceptType T (NOLOCK)
            ON C.ConceptType = T.ConceptType
    WHERE C.Company = @company
      AND C.FormulaCode IS NOT NULL
      AND LTRIM(RTRIM(C.FormulaCode)) <> ''
      AND (
            @descripcion IS NULL
         OR C.Description LIKE '%' + @descripcion + '%'
         OR C.FormulaCode LIKE '%' + @descripcion + '%'
         OR C.PrintText LIKE '%' + @descripcion + '%'
      )
      AND (
            @tipos IS NULL
         OR EXISTS (
                SELECT 1
                FROM @tipos_filtro tf
                WHERE tf.shortname = UPPER(LTRIM(RTRIM(ISNULL(T.ShortName, ''))))
            )
      );

    CREATE TABLE #incidencias (
        tipo_validacion VARCHAR(12) NOT NULL,
        company_destino VARCHAR(10) NOT NULL,
        company_desc    VARCHAR(100) NULL,
        formulacode     VARCHAR(20) NOT NULL,
        description     VARCHAR(50) NULL,
        tiposhortname   VARCHAR(10) NULL,
        campo           VARCHAR(40) NULL,
        valor_origen    VARCHAR(100) NULL,
        valor_destino   VARCHAR(100) NULL
    );

    INSERT INTO #incidencias (
        tipo_validacion, company_destino, company_desc, formulacode,
        description, tiposhortname, campo, valor_origen, valor_destino
    )
    SELECT
        'FALTANTE',
        sc.Company,
        ISNULL(sc.description, sc.Company),
        o.formulacode,
        o.description,
        o.tiposhortname,
        NULL,
        NULL,
        NULL
    FROM SY_Company sc (NOLOCK)
        CROSS JOIN #origen o
    WHERE sc.status = 'A'
      AND sc.Company <> @company
      AND NOT EXISTS (
            SELECT 1
            FROM PR_Concept c2 (NOLOCK)
            WHERE c2.Company = sc.Company
              AND LTRIM(RTRIM(c2.FormulaCode)) = o.formulacode
        );

    SELECT
        sc.Company AS company_destino,
        ISNULL(sc.description, sc.Company) AS company_desc,
        o.formulacode,
        o.description,
        o.tiposhortname,
        o.pdt AS o_pdt,
        ISNULL(LTRIM(RTRIM(C.pdt)), '') AS d_pdt,
        o.flaginsertar AS o_flaginsertar,
        ISNULL(UPPER(LTRIM(RTRIM(C.flaginsertar))), 'N') AS d_flaginsertar,
        o.flagafecto5ta AS o_flagafecto5ta,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafecto5ta))), 'N') AS d_flagafecto5ta,
        o.flagafectoafp AS o_flagafectoafp,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafectoAFP))), 'N') AS d_flagafectoafp
    INTO #pares
    FROM SY_Company sc (NOLOCK)
        CROSS JOIN #origen o
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Company = sc.Company
           AND LTRIM(RTRIM(C.FormulaCode)) = o.formulacode
    WHERE sc.status = 'A'
      AND sc.Company <> @company;

    INSERT INTO #incidencias (
        tipo_validacion, company_destino, company_desc, formulacode,
        description, tiposhortname, campo, valor_origen, valor_destino
    )
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'PDT', o_pdt, d_pdt FROM #pares WHERE o_pdt <> d_pdt
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Insertar en', o_flaginsertar, d_flaginsertar FROM #pares WHERE o_flaginsertar <> d_flaginsertar
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Afecto 5ta', o_flagafecto5ta, d_flagafecto5ta FROM #pares WHERE o_flagafecto5ta <> d_flagafecto5ta
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Afecto AFP', o_flagafectoafp, d_flagafectoafp FROM #pares WHERE o_flagafectoafp <> d_flagafectoafp;

    SELECT COUNT(*) AS total_origen FROM #origen;

    SELECT
        company_destino,
        company_desc,
        SUM(CASE WHEN tipo_validacion = 'FALTANTE' THEN 1 ELSE 0 END) AS faltantes,
        SUM(CASE WHEN tipo_validacion = 'DIFERENCIA' THEN 1 ELSE 0 END) AS diferencias,
        COUNT(*) AS total_incidencias
    FROM #incidencias
    GROUP BY company_destino, company_desc
    ORDER BY company_destino ASC;

    SELECT
        tipo_validacion,
        company_destino,
        company_desc,
        formulacode,
        description,
        tiposhortname,
        campo,
        valor_origen,
        valor_destino
    FROM #incidencias
    ORDER BY
        company_destino ASC,
        tipo_validacion ASC,
        formulacode ASC,
        campo ASC;

    DROP TABLE #incidencias;
    DROP TABLE #pares;
    DROP TABLE #origen;
END
GO
