/*
    Listado maestro de fórmulas por compañía, tipo de planilla y proceso.
    Usado por: POST /api/formulas/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarformulas_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));

    IF @company = '' OR @payrolltype = '' OR @processtype = ''
    BEGIN
        RAISERROR('Indique compañía, tipo de planilla y proceso.', 16, 1);
        RETURN;
    END;

    SELECT
        fh.FormulaHeader AS formulaheader,
        fh.Company AS company,
        fh.Payrolltype AS payrolltype,
        fh.Proccestype AS proccestype,
        fh.Concept AS concept,
        fh.Description AS description,
        fh.orden,
        c.Description AS concepto,
        ct.Description AS tipo,
        cc.Description AS condicion,
        gf.name AS grupo,
        fh.formulacode,
        'N' AS flag,
        (
            SELECT MAX(fd.XLastDate)
            FROM PR_FormulaDetail fd (NOLOCK)
            WHERE fd.FormulaHeader = fh.FormulaHeader
        ) AS ultimafecha
    FROM PR_FormulaHeader fh (NOLOCK)
        INNER JOIN PR_Concept c (NOLOCK)
            ON fh.Concept = c.Concept
           AND fh.Company = c.Company
        INNER JOIN PR_ConceptType ct (NOLOCK)
            ON c.ConceptType = ct.ConceptType
        INNER JOIN PR_GrupoFormula gf (NOLOCK)
            ON fh.GrupoFormula = gf.GrupoFormula
           AND fh.Company = gf.Company
        LEFT JOIN PR_Concept cc (NOLOCK)
            ON fh.ConceptCond = cc.Concept
           AND fh.Company = cc.Company
    WHERE fh.Company = @company
      AND fh.Payrolltype = @payrolltype
      AND fh.Proccestype = @processtype
    ORDER BY fh.orden ASC, fh.FormulaHeader ASC;
END
GO
