/*
    Selector de grupos de fórmula por compañía.
    Usado por: GET /api/selectores/grupos-formula
               GET /api/formulas/selectores-edicion

    Nota: PR_GrupoFormula tiene PK solo en GrupoFormula (catálogo global).
    En multi-compañía (p.ej. hm_alamo) los grupos suelen estar cargados
    solo en Company='BGT'. Si la compañía pedida no tiene filas, se usa BGT;
    si BGT tampoco tiene (p.ej. hm_zilicom, donde están en SB01), se devuelve
    el catálogo completo, porque el grupo es único para todas las empresas.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorgrupoformula_web]
    @company VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));

    DECLARE @cia_grp VARCHAR(20) = @company;

    IF @cia_grp = ''
       OR NOT EXISTS (
            SELECT 1
            FROM PR_GrupoFormula gf (NOLOCK)
            WHERE gf.Company = @cia_grp
       )
    BEGIN
        SET @cia_grp = 'BGT';
    END;

    -- BGT tampoco tiene grupos: el catálogo es global (PK = GrupoFormula),
    -- se devuelven los grupos de cualquier compañía que los tenga cargados.
    IF NOT EXISTS (
            SELECT 1
            FROM PR_GrupoFormula gf (NOLOCK)
            WHERE gf.Company = @cia_grp
       )
    BEGIN
        SET @cia_grp = NULL;
    END;

    SELECT
        gf.GrupoFormula AS id,
        gf.Name AS text,
        gf.GroupOrder AS grouporder
    FROM PR_GrupoFormula gf (NOLOCK)
    WHERE @cia_grp IS NULL
       OR gf.Company = @cia_grp
    ORDER BY gf.GroupOrder ASC, gf.Name ASC;
END
GO
