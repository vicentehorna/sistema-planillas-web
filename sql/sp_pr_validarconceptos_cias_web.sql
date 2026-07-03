/*
    Valida conceptos filtrados de una compañía frente a las demás empresas activas:
      - FALTANTE: no existe el nemónico (FormulaCode) en destino
      - DIFERENCIA: existe pero algún atributo no coincide con la compañía origen

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
        ISNULL(T.Description, '') AS tipodescription,
        ISNULL(C.PrintText, '') AS printtext,
        ISNULL(UPPER(LTRIM(RTRIM(T.ShortName))), '') AS concepttype_short,
        ISNULL(UPPER(LTRIM(RTRIM(C.ConceptCurrency))), 'LO') AS conceptcurrency,
        ISNULL(UPPER(LTRIM(RTRIM(C.FlagIsMonetary))), 'N') AS flagismonetary,
        ISNULL(UPPER(LTRIM(RTRIM(C.Flagassign))), 'N') AS flagassign,
        ISNULL(CAST(C.ConceptOrder AS VARCHAR(11)), '') AS conceptorder,
        ISNULL(UPPER(LTRIM(RTRIM(C.FlagPayrollTicket))), 'N') AS flagpayrollticket,
        ISNULL(CAST(C.reporden AS VARCHAR(11)), '') AS reporden,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagconceptdeclare))), 'N') AS flagconceptdeclare,
        ISNULL(LTRIM(RTRIM(C.pdt)), '') AS pdt,
        ISNULL(UPPER(LTRIM(RTRIM(C.FLAGCONTRACT))), 'N') AS flagcontract,
        ISNULL(UPPER(LTRIM(RTRIM(C.Status))), 'A') AS status,
        ISNULL(UPPER(LTRIM(RTRIM(C.flaginsertar))), 'N') AS flaginsertar,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafecto5ta))), 'N') AS flagafecto5ta,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafectoAFP))), 'N') AS flagafectoafp,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafectoUtilidad))), 'N') AS flagafectoutilidad
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
        o.description AS o_description,
        ISNULL(C.Description, '') AS d_description,
        o.printtext AS o_printtext,
        ISNULL(C.PrintText, '') AS d_printtext,
        o.concepttype_short AS o_concepttype_short,
        ISNULL(UPPER(LTRIM(RTRIM(T2.ShortName))), '') AS d_concepttype_short,
        o.conceptcurrency AS o_conceptcurrency,
        ISNULL(UPPER(LTRIM(RTRIM(C.ConceptCurrency))), 'LO') AS d_conceptcurrency,
        o.flagismonetary AS o_flagismonetary,
        ISNULL(UPPER(LTRIM(RTRIM(C.FlagIsMonetary))), 'N') AS d_flagismonetary,
        o.flagassign AS o_flagassign,
        ISNULL(UPPER(LTRIM(RTRIM(C.Flagassign))), 'N') AS d_flagassign,
        o.conceptorder AS o_conceptorder,
        ISNULL(CAST(C.ConceptOrder AS VARCHAR(11)), '') AS d_conceptorder,
        o.flagpayrollticket AS o_flagpayrollticket,
        ISNULL(UPPER(LTRIM(RTRIM(C.FlagPayrollTicket))), 'N') AS d_flagpayrollticket,
        o.reporden AS o_reporden,
        ISNULL(CAST(C.reporden AS VARCHAR(11)), '') AS d_reporden,
        o.flagconceptdeclare AS o_flagconceptdeclare,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagconceptdeclare))), 'N') AS d_flagconceptdeclare,
        o.pdt AS o_pdt,
        ISNULL(LTRIM(RTRIM(C.pdt)), '') AS d_pdt,
        o.flagcontract AS o_flagcontract,
        ISNULL(UPPER(LTRIM(RTRIM(C.FLAGCONTRACT))), 'N') AS d_flagcontract,
        o.status AS o_status,
        ISNULL(UPPER(LTRIM(RTRIM(C.Status))), 'A') AS d_status,
        o.flaginsertar AS o_flaginsertar,
        ISNULL(UPPER(LTRIM(RTRIM(C.flaginsertar))), 'N') AS d_flaginsertar,
        o.flagafecto5ta AS o_flagafecto5ta,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafecto5ta))), 'N') AS d_flagafecto5ta,
        o.flagafectoafp AS o_flagafectoafp,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafectoAFP))), 'N') AS d_flagafectoafp,
        o.flagafectoutilidad AS o_flagafectoutilidad,
        ISNULL(UPPER(LTRIM(RTRIM(C.flagafectoUtilidad))), 'N') AS d_flagafectoutilidad
    INTO #pares
    FROM SY_Company sc (NOLOCK)
        CROSS JOIN #origen o
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Company = sc.Company
           AND LTRIM(RTRIM(C.FormulaCode)) = o.formulacode
        LEFT JOIN PR_ConceptType T2 (NOLOCK)
            ON C.ConceptType = T2.ConceptType
    WHERE sc.status = 'A'
      AND sc.Company <> @company;

    INSERT INTO #incidencias (
        tipo_validacion, company_destino, company_desc, formulacode,
        description, tiposhortname, campo, valor_origen, valor_destino
    )
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Descripción', o_description, d_description FROM #pares WHERE o_description <> d_description
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Impresión', o_printtext, d_printtext FROM #pares WHERE o_printtext <> d_printtext
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Tipo concepto', o_concepttype_short, d_concepttype_short FROM #pares WHERE o_concepttype_short <> d_concepttype_short
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Moneda', o_conceptcurrency, d_conceptcurrency FROM #pares WHERE o_conceptcurrency <> d_conceptcurrency
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Es importe', o_flagismonetary, d_flagismonetary FROM #pares WHERE o_flagismonetary <> d_flagismonetary
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Asignación', o_flagassign, d_flagassign FROM #pares WHERE o_flagassign <> d_flagassign
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Orden boleta', o_conceptorder, d_conceptorder FROM #pares WHERE o_conceptorder <> d_conceptorder
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Orden planilla', o_reporden, d_reporden FROM #pares WHERE o_reporden <> d_reporden
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Boleta', o_flagpayrollticket, d_flagpayrollticket FROM #pares WHERE o_flagpayrollticket <> d_flagpayrollticket
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Declara concepto', o_flagconceptdeclare, d_flagconceptdeclare FROM #pares WHERE o_flagconceptdeclare <> d_flagconceptdeclare
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'PDT', o_pdt, d_pdt FROM #pares WHERE o_pdt <> d_pdt
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Contrato', o_flagcontract, d_flagcontract FROM #pares WHERE o_flagcontract <> d_flagcontract
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Estado', o_status, d_status FROM #pares WHERE o_status <> d_status
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Insertar', o_flaginsertar, d_flaginsertar FROM #pares WHERE o_flaginsertar <> d_flaginsertar
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Afecto 5ta', o_flagafecto5ta, d_flagafecto5ta FROM #pares WHERE o_flagafecto5ta <> d_flagafecto5ta
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Afecto AFP', o_flagafectoafp, d_flagafectoafp FROM #pares WHERE o_flagafectoafp <> d_flagafectoafp
    UNION ALL
    SELECT 'DIFERENCIA', company_destino, company_desc, formulacode, description, tiposhortname, 'Afecto utilidad', o_flagafectoutilidad, d_flagafectoutilidad FROM #pares WHERE o_flagafectoutilidad <> d_flagafectoutilidad;

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
