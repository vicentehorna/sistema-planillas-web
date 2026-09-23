/*
    Replica una fórmula (FormulaHeader) de @cia hacia otras compañías.

    @cia_destino (opcional):
      - NULL / ''  → replica a todas las empresas activas (comportamiento histórico).
      - Código CIA → replica solo a esa empresa destino.

    Incluye detalle Tipo K (Código/parser): copia ScriptSource + CompiledExpr
    tal cual están en origen (el parser se ejecuta al Guardar en la UI;
    al Replicar se propaga el código fuente y la expresión compilada).

    Corrección respecto a versión anterior:
      - Al buscar fórmula destino a reemplazar, filtra por proceso con
        pt.ProcessType = fh.Proccestype (no usar columna inexistente Proccestype
        en PR_ProcessType, que hacía coincidir formulacodes de otros procesos).
      - Solo elimina cabecera/detalle si @idformula <> ''.
      - Joins de Concept/Parameter/Process del detalle filtrados por compañía origen.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_replicar_formula_cia]
    @cia           VARCHAR(4),
    @formulacode   VARCHAR(50),
    @formulaheader VARCHAR(20),
    @cia_destino   VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id         VARCHAR(20);
    DECLARE @company    VARCHAR(20);
    DECLARE @planilla   VARCHAR(50);
    DECLARE @proceso    VARCHAR(50);
    DECLARE @idformula  VARCHAR(20);

    SET @cia_destino = NULLIF(LTRIM(RTRIM(ISNULL(@cia_destino, ''))), '');

    IF @cia_destino IS NOT NULL AND @cia_destino = LTRIM(RTRIM(ISNULL(@cia, '')))
    BEGIN
        RAISERROR('La empresa destino debe ser distinta a la de origen.', 16, 1);
        RETURN;
    END;

    IF @cia_destino IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM SY_Company
            WHERE LTRIM(RTRIM(Company)) = @cia_destino
              AND ISNULL(status, 'A') = 'A'
       )
    BEGIN
        RAISERROR('La empresa destino no existe o no está activa.', 16, 1);
        RETURN;
    END;

    SELECT
        @planilla = PR_PayRollType.ShortName,
        @proceso  = PR_ProcessType.ShortName
    FROM PR_FormulaHeader
    INNER JOIN PR_PayRollType
        ON PR_FormulaHeader.Payrolltype = PR_PayRollType.PayRollType
    INNER JOIN PR_ProcessType
        ON PR_FormulaHeader.Proccestype = PR_ProcessType.ProcessType
    LEFT JOIN PR_Concept C
        ON PR_FormulaHeader.ConceptCond = C.Concept
       AND C.Company = PR_FormulaHeader.Company
    WHERE PR_FormulaHeader.Company = @cia
      AND PR_FormulaHeader.FormulaHeader = @formulaheader;

    -- FormulaCode autoritativo: el del concepto de la fórmula origen (no fh.formulacode, puede estar desactualizado).
    SELECT @formulacode = LTRIM(RTRIM(ISNULL(c.FormulaCode, '')))
    FROM PR_FormulaHeader fh
    INNER JOIN PR_Concept c
        ON fh.Concept = c.Concept AND fh.Company = c.Company
    WHERE fh.Company = @cia
      AND fh.FormulaHeader = @formulaheader;

    IF @formulacode IS NULL OR @formulacode = ''
    BEGIN
        SELECT @formulacode = LTRIM(RTRIM(ISNULL(fh.formulacode, '')))
        FROM PR_FormulaHeader fh
        WHERE fh.Company = @cia
          AND fh.FormulaHeader = @formulaheader;
    END

    SET @formulacode = NULLIF(LTRIM(RTRIM(@formulacode)), '');

    DECLARE empresas CURSOR LOCAL FAST_FORWARD FOR
        SELECT Company
        FROM SY_Company
        WHERE Company <> @cia
          AND ISNULL(status, 'A') = 'A'
          AND (
                @cia_destino IS NULL
             OR LTRIM(RTRIM(Company)) = @cia_destino
          );

    OPEN empresas;
    FETCH NEXT FROM empresas INTO @company;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM PR_Concept
            WHERE Company = @company
              AND LTRIM(RTRIM(FormulaCode)) = LTRIM(RTRIM(@formulacode))
        )
        AND EXISTS (
            SELECT 1 FROM PR_PayRollType T
            WHERE T.Company = @company AND T.ShortName = @planilla
        )
        AND EXISTS (
            SELECT 1 FROM PR_ProcessType M
            WHERE M.Company = @company AND M.ShortName = @proceso
        )
        BEGIN
        SET @idformula = ISNULL((
            SELECT fh.FormulaHeader
            FROM PR_FormulaHeader fh
            INNER JOIN PR_Concept c_dest
                ON fh.Concept = c_dest.Concept
               AND fh.Company = c_dest.Company
               AND LTRIM(RTRIM(c_dest.FormulaCode)) = LTRIM(RTRIM(@formulacode))
            WHERE fh.Company = @company
              AND EXISTS (
                    SELECT 1
                    FROM PR_ProcessType pt
                    WHERE pt.Company = @company
                      AND pt.ShortName = @proceso
                      AND pt.ProcessType = fh.Proccestype
              )
              AND EXISTS (
                    SELECT 1
                    FROM PR_PayRollType prt
                    WHERE prt.Company = @company
                      AND prt.ShortName = @planilla
                      AND prt.Payrolltype = fh.Payrolltype
              )
        ), '');

        IF @idformula <> ''
        BEGIN
            DELETE FROM PR_FormulaDetail WHERE FormulaHeader = @idformula;
            DELETE FROM PR_FormulaHeader WHERE FormulaHeader = @idformula;
        END

        EXEC SP_SY_ObjectSecuence_Edit 'PRA_FORM2024', @company, 'LIMA', @id OUTPUT;

        INSERT INTO PR_FormulaHeader (
            FormulaHeader, Company, Payrolltype, Proccestype, Concept, Description,
            orden, XLastUser, XLastDate, period, person, Tipo, ConceptCond,
            GrupoFormula, flagtruncate, formulacode, parametroformula
        )
        SELECT
            @id,
            @company,
            (SELECT Payrolltype FROM PR_PayRollType T WHERE T.Company = @company AND T.ShortName = PR_PayRollType.ShortName),
            (SELECT ProcessType FROM PR_ProcessType M WHERE M.Company = @company AND M.ShortName = PR_ProcessType.ShortName),
            (SELECT Concept FROM PR_Concept WHERE LTRIM(RTRIM(FormulaCode)) = LTRIM(RTRIM(@formulacode)) AND Company = @company),
            PR_FormulaHeader.Description,
            orden,
            'MASIVO',
            GETDATE(),
            period,
            person,
            tipo,
            (SELECT Concept FROM PR_Concept T WHERE T.FormulaCode = C.FormulaCode AND T.Company = @company),
            PR_FormulaHeader.GrupoFormula,
            flagtruncate,
            @formulacode,
            PR_FormulaHeader.parametroformula
        FROM PR_FormulaHeader
        INNER JOIN PR_PayRollType
            ON PR_FormulaHeader.Payrolltype = PR_PayRollType.PayRollType
        INNER JOIN PR_ProcessType
            ON PR_FormulaHeader.Proccestype = PR_ProcessType.ProcessType
        LEFT JOIN PR_Concept C
            ON PR_FormulaHeader.ConceptCond = C.Concept
           AND C.Company = PR_FormulaHeader.Company
        WHERE PR_FormulaHeader.Company = @cia
          AND PR_FormulaHeader.FormulaHeader = @formulaheader;

        /* Tipo K (Código/parser): copia ScriptSource + CompiledExpr del origen. */
        INSERT INTO PR_FormulaDetail (
            FormulaHeader, line, company, Tipo, Operador, Concept, grupo, valor,
            XLastUser, XLastDate, parameter, process, PeriodoINI, PeriodoFin,
            NumberINI, NumberFIN, TipoLiq, ConceptList, Divisor,
            ScriptSource, CompiledExpr
        )
        SELECT
            @id,
            fd.line,
            @company,
            fd.tipo,
            fd.Operador,
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(C.FormulaCode, ''))), '') IS NULL THEN NULL
                ELSE (
                    SELECT TOP 1 c2.Concept
                    FROM PR_Concept c2
                    WHERE c2.Company = @company
                      AND LTRIM(RTRIM(ISNULL(c2.FormulaCode, ''))) = LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))
                    ORDER BY c2.Concept
                )
            END,
            fd.grupo,
            fd.valor,
            'MASIVO',
            GETDATE(),
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(P.shortname, ''))), '') IS NULL THEN NULL
                ELSE (
                    SELECT TOP 1 T.parameter
                    FROM PR_Parameter T
                    WHERE T.Company = @company
                      AND LTRIM(RTRIM(ISNULL(T.shortname, ''))) = LTRIM(RTRIM(ISNULL(P.shortname, '')))
                    ORDER BY T.parameter
                )
            END,
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(PR_ProcessType.ShortName, ''))), '') IS NULL THEN NULL
                ELSE (
                    SELECT TOP 1 T.ProcessType
                    FROM PR_ProcessType T
                    WHERE T.Company = @company
                      AND LTRIM(RTRIM(ISNULL(T.ShortName, ''))) = LTRIM(RTRIM(ISNULL(PR_ProcessType.ShortName, '')))
                    ORDER BY T.ProcessType
                )
            END,
            fd.PeriodoINI,
            fd.PeriodoFin,
            fd.NumberINI,
            fd.NumberFIN,
            fd.TipoLiq,
            dbo.f_map_conceptlist_cia(fd.ConceptList, @cia, @company),
            fd.Divisor,
            fd.ScriptSource,
            fd.CompiledExpr
        FROM PR_FormulaDetail fd
        LEFT JOIN PR_Concept C
            ON fd.Concept = C.Concept
           AND C.Company = ISNULL(NULLIF(LTRIM(RTRIM(fd.company)), ''), @cia)
        LEFT JOIN PR_Parameter P
            ON fd.parameter = P.parameter
           AND P.Company = ISNULL(NULLIF(LTRIM(RTRIM(fd.company)), ''), @cia)
        LEFT JOIN PR_ProcessType
            ON fd.process = PR_ProcessType.ProcessType
           AND PR_ProcessType.Company = ISNULL(NULLIF(LTRIM(RTRIM(fd.company)), ''), @cia)
        WHERE fd.FormulaHeader = @formulaheader;

        END

        FETCH NEXT FROM empresas INTO @company;
    END

    CLOSE empresas;
    DEALLOCATE empresas;
END
GO
