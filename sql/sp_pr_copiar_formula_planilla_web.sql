/*
    Copia una fórmula de un tipo de planilla a otro dentro de la misma compañía.

    - Si en destino ya existe (mismo FormulaCode + mismo proceso + planilla destino),
      se elimina y se vuelve a crear igual al origen.
    - Si no existe, se inserta nueva cabecera y detalle.

    Usado por: POST /api/formulas/copiar-planilla
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_copiar_formula_planilla_web]
    @cia              VARCHAR(4),
    @formulaheader    VARCHAR(20),
    @payrolltype_dest VARCHAR(20),
    @xlastuser        VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id            VARCHAR(20);
    DECLARE @payroll_orig    VARCHAR(20);
    DECLARE @proccestype     VARCHAR(20);
    DECLARE @formulacode     VARCHAR(50);
    DECLARE @idformula_dest  VARCHAR(20);
    DECLARE @accion          VARCHAR(10);

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @formulaheader = LTRIM(RTRIM(ISNULL(@formulaheader, '')));
    SET @payrolltype_dest = LTRIM(RTRIM(ISNULL(@payrolltype_dest, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = '' OR @formulaheader = '' OR @payrolltype_dest = ''
    BEGIN
        RAISERROR('Indique compañía, fórmula origen y planilla destino.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_FormulaHeader fh
        WHERE fh.Company = @cia AND fh.FormulaHeader = @formulaheader
    )
    BEGIN
        RAISERROR('No existe la fórmula origen indicada.', 16, 1);
        RETURN;
    END;

    SELECT
        @payroll_orig = fh.Payrolltype,
        @proccestype  = fh.Proccestype
    FROM PR_FormulaHeader fh
    WHERE fh.Company = @cia AND fh.FormulaHeader = @formulaheader;

    IF @payrolltype_dest = @payroll_orig
    BEGIN
        RAISERROR('La planilla destino debe ser distinta a la planilla origen.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_PayRollType prt
        WHERE prt.Company = @cia AND prt.PayRollType = @payrolltype_dest
    )
    BEGIN
        RAISERROR('La planilla destino no existe en la compañía.', 16, 1);
        RETURN;
    END;

    SELECT @formulacode = LTRIM(RTRIM(ISNULL(c.FormulaCode, '')))
    FROM PR_FormulaHeader fh
    LEFT JOIN PR_Concept c
        ON fh.Concept = c.Concept AND fh.Company = c.Company
    WHERE fh.Company = @cia AND fh.FormulaHeader = @formulaheader;

    IF @formulacode IS NULL OR @formulacode = ''
    BEGIN
        SELECT @formulacode = LTRIM(RTRIM(ISNULL(fh.formulacode, '')))
        FROM PR_FormulaHeader fh
        WHERE fh.Company = @cia AND fh.FormulaHeader = @formulaheader;
    END;

    SET @formulacode = NULLIF(LTRIM(RTRIM(@formulacode)), '');

    SET @idformula_dest = ISNULL((
        SELECT TOP 1 fh.FormulaHeader
        FROM PR_FormulaHeader fh
        LEFT JOIN PR_Concept c
            ON fh.Concept = c.Concept AND fh.Company = c.Company
        WHERE fh.Company = @cia
          AND fh.Payrolltype = @payrolltype_dest
          AND fh.Proccestype = @proccestype
          AND (
                (@formulacode IS NOT NULL AND LTRIM(RTRIM(ISNULL(c.FormulaCode, fh.formulacode))) = @formulacode)
                OR (@formulacode IS NULL AND fh.Concept = (
                        SELECT Concept FROM PR_FormulaHeader s
                        WHERE s.Company = @cia AND s.FormulaHeader = @formulaheader
                    ))
              )
        ORDER BY fh.FormulaHeader
    ), '');

    IF @idformula_dest <> ''
    BEGIN
        DELETE FROM PR_FormulaDetail WHERE FormulaHeader = @idformula_dest;
        DELETE FROM PR_FormulaHeader WHERE FormulaHeader = @idformula_dest;
        SET @accion = 'UPDATE';
    END
    ELSE
        SET @accion = 'INSERT';

    EXEC SP_SY_ObjectSecuence_Edit 'PRA_FORM2024', @cia, 'LIMA', @id OUTPUT;

    IF @id IS NULL OR LTRIM(RTRIM(@id)) = ''
    BEGIN
        RAISERROR('No se pudo generar el identificador de fórmula.', 16, 1);
        RETURN;
    END;

    INSERT INTO PR_FormulaHeader (
        FormulaHeader, Company, Payrolltype, Proccestype, Concept, Description,
        orden, XLastUser, XLastDate, period, person, Tipo, ConceptCond,
        GrupoFormula, flagtruncate, formulacode, parametroformula
    )
    SELECT
        @id,
        fh.Company,
        @payrolltype_dest,
        fh.Proccestype,
        fh.Concept,
        fh.Description,
        fh.orden,
        ISNULL(@xlastuser, 'WEB'),
        GETDATE(),
        fh.period,
        fh.person,
        fh.Tipo,
        fh.ConceptCond,
        fh.GrupoFormula,
        fh.flagtruncate,
        ISNULL(@formulacode, fh.formulacode),
        fh.parametroformula
    FROM PR_FormulaHeader fh
    WHERE fh.Company = @cia AND fh.FormulaHeader = @formulaheader;

    INSERT INTO PR_FormulaDetail (
        FormulaHeader, line, company, Tipo, Operador, Concept, grupo, valor,
        XLastUser, XLastDate, parameter, process, PeriodoINI, PeriodoFin,
        NumberINI, NumberFIN, TipoLiq, ConceptList, Divisor
    )
    SELECT
        @id,
        fd.line,
        fd.company,
        fd.Tipo,
        fd.Operador,
        fd.Concept,
        fd.grupo,
        fd.valor,
        ISNULL(@xlastuser, 'WEB'),
        GETDATE(),
        fd.parameter,
        fd.process,
        fd.PeriodoINI,
        fd.PeriodoFin,
        fd.NumberINI,
        fd.NumberFIN,
        fd.TipoLiq,
        fd.ConceptList,
        fd.Divisor
    FROM PR_FormulaDetail fd
    WHERE fd.FormulaHeader = @formulaheader;

    SELECT
        @id AS formulaheader,
        @accion AS accion,
        @formulacode AS formulacode,
        @payrolltype_dest AS payrolltype_dest;
END
GO
