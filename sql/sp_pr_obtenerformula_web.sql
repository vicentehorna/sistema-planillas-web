/*
    Cabecera y detalle de una fórmula (dos resultsets).
    Usado por: POST /api/formulas/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerformula_web]
    @company       VARCHAR(4),
    @formulaheader VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @formulaheader = LTRIM(RTRIM(ISNULL(@formulaheader, '')));

    IF @company = '' OR @formulaheader = ''
    BEGIN
        RAISERROR('Indique compañía y fórmula.', 16, 1);
        RETURN;
    END;

    -- Resultset 1: cabecera
    SELECT
        fh.FormulaHeader AS formulaheader,
        fh.Company AS company,
        fh.Payrolltype AS payrolltype,
        fh.Proccestype AS proccestype,
        fh.Concept AS concept,
        c.Description AS concepto_desc,
        fh.Description AS description,
        fh.orden,
        fh.XLastUser AS xlastuser,
        fh.XLastDate AS xlastdate,
        fh.person,
        fh.period,
        fh.Tipo AS tipo,
        fh.ConceptCond AS conceptcond,
        cc.Description AS conceptcond_desc,
        fh.GrupoFormula AS grupoformula,
        gf.name AS grupoformula_desc,
        fh.flagtruncate,
        fh.formulacode,
        fh.parametroformula,
        pf.Name AS parametroformula_desc
    FROM PR_FormulaHeader fh (NOLOCK)
        LEFT JOIN PR_Concept c (NOLOCK)
            ON fh.Concept = c.Concept
           AND fh.Company = c.Company
        LEFT JOIN PR_Concept cc (NOLOCK)
            ON fh.ConceptCond = cc.Concept
           AND fh.Company = cc.Company
        LEFT JOIN PR_GrupoFormula gf (NOLOCK)
            ON fh.GrupoFormula = gf.GrupoFormula
           AND fh.Company = gf.Company
        LEFT JOIN PR_ParametroFormula pf (NOLOCK)
            ON fh.parametroformula = pf.ParametroFormula
    WHERE fh.Company = @company
      AND fh.FormulaHeader = @formulaheader;

    -- Resultset 2: detalle
    SELECT
        fd.FormulaHeader AS formulaheader,
        fd.line,
        fd.company,
        fd.Tipo AS tipo,
        fd.Operador AS operador,
        fd.Concept AS concept,
        c.Description AS concepto,
        fd.grupo,
        fd.valor,
        fd.XLastUser AS xlastuser,
        fd.XLastDate AS xlastdate,
        fd.parameter,
        p.ShortName AS parameter_desc,
        fd.process,
        pt.Description AS process_desc,
        fd.PeriodoINI AS periodoini,
        fd.PeriodoFin AS periodofin,
        fd.NumberINI AS numberini,
        fd.NumberFIN AS numberfin,
        fd.TipoLiq AS tipoliq,
        fd.ConceptList AS conceptlist,
        fd.Divisor AS divisor
    FROM PR_FormulaDetail fd (NOLOCK)
        LEFT JOIN PR_Concept c (NOLOCK)
            ON fd.Concept = c.Concept
           AND fd.company = c.Company
        LEFT JOIN PR_Parameter p (NOLOCK)
            ON fd.parameter = p.Parameter
           AND fd.company = p.Company
        LEFT JOIN PR_ProcessType pt (NOLOCK)
            ON fd.process = pt.ProcessType
           AND fd.company = pt.Company
    WHERE fd.FormulaHeader = @formulaheader
    ORDER BY fd.line ASC;
END
GO
