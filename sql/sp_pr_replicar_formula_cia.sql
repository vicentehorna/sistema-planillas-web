/*
    Replica una fórmula (FormulaHeader) de @cia hacia el resto de compañías.

    Corrección respecto a versión anterior:
      - Al buscar fórmula destino a reemplazar, filtra por proceso con
        pt.ProcessType = fh.Proccestype (no usar columna inexistente Proccestype
        en PR_ProcessType, que hacía coincidir formulacodes de otros procesos).
      - Solo elimina cabecera/detalle si @idformula <> ''.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_replicar_formula_cia]
    @cia           VARCHAR(4),
    @formulacode   VARCHAR(50),
    @formulaheader VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id         VARCHAR(20);
    DECLARE @company    VARCHAR(20);
    DECLARE @planilla   VARCHAR(50);
    DECLARE @proceso    VARCHAR(50);
    DECLARE @idformula  VARCHAR(20);

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
    WHERE PR_FormulaHeader.Company = @cia
      AND PR_FormulaHeader.FormulaHeader = @formulaheader;

    IF @formulacode IS NULL OR LTRIM(RTRIM(@formulacode)) = ''
    BEGIN
        SELECT @formulacode = LTRIM(RTRIM(ISNULL(c.FormulaCode, fh.formulacode)))
        FROM PR_FormulaHeader fh
        LEFT JOIN PR_Concept c
            ON fh.Concept = c.Concept AND fh.Company = c.Company
        WHERE fh.Company = @cia
          AND fh.FormulaHeader = @formulaheader;
    END

    DECLARE empresas CURSOR LOCAL FAST_FORWARD FOR
        SELECT Company
        FROM SY_Company
        WHERE Company <> @cia
          AND ISNULL(status, 'A') = 'A';

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
            GrupoFormula, flagtruncate, formulacode
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
            GrupoFormula,
            flagtruncate,
            PR_FormulaHeader.formulacode
        FROM PR_FormulaHeader
        INNER JOIN PR_PayRollType
            ON PR_FormulaHeader.Payrolltype = PR_PayRollType.PayRollType
        INNER JOIN PR_ProcessType
            ON PR_FormulaHeader.Proccestype = PR_ProcessType.ProcessType
        LEFT JOIN PR_Concept C
            ON PR_FormulaHeader.ConceptCond = C.Concept
        WHERE PR_FormulaHeader.Company = @cia
          AND PR_FormulaHeader.FormulaHeader = @formulaheader;

        INSERT INTO PR_FormulaDetail (
            FormulaHeader, line, company, Tipo, Operador, Concept, grupo, valor,
            XLastUser, XLastDate, parameter, process, PeriodoINI, PeriodoFin,
            NumberINI, NumberFIN, TipoLiq
        )
        SELECT
            @id,
            line,
            @company,
            tipo,
            Operador,
            (SELECT Concept FROM PR_Concept WHERE FormulaCode = C.formulacode AND Company = @company),
            grupo,
            valor,
            'MASIVO',
            GETDATE(),
            (SELECT parameter FROM PR_Parameter T WHERE T.shortname = P.shortname AND T.Company = @company),
            (SELECT T.ProcessType FROM PR_ProcessType T WHERE T.Company = @company AND T.ShortName = PR_ProcessType.ShortName),
            PeriodoINI,
            PeriodoFin,
            NumberINI,
            NumberFIN,
            TipoLiq
        FROM PR_FormulaDetail
        LEFT JOIN PR_Concept C
            ON PR_FormulaDetail.Concept = C.Concept
        LEFT JOIN PR_Parameter P
            ON PR_FormulaDetail.parameter = P.parameter
        LEFT JOIN PR_ProcessType
            ON PR_FormulaDetail.process = PR_ProcessType.ProcessType
        WHERE PR_FormulaDetail.FormulaHeader = @formulaheader;

        END

        FETCH NEXT FROM empresas INTO @company;
    END

    CLOSE empresas;
    DEALLOCATE empresas;
END
GO
