/*
    Listado de configuración de conceptos 5ta por compañía.
    Usado por: POST /api/configura5ta/listado

    PK lógica: Company + Type + line
    Type: IN=Ingresos, LI=Liquidación, UT=Utilidades, RE=Retenciones
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_configura5ta_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        C.Company AS company,
        C.Type AS type,
        C.line AS line,
        C.Plame AS plame,
        C.ProcessType AS processtype,
        ISNULL(PT.Description, C.ProcessType) AS proceso,
        ISNULL(PT.ShortName, '') AS proceso_shortname,
        C.Concept AS concept,
        ISNULL(CT.Description, C.Concept) AS concepto,
        ISNULL(CT.FormulaCode, '') AS formulacode,
        ISNULL(C.ApplySum, 'P') AS applysum,
        CASE WHEN ISNULL(C.ApplySum, 'P') = 'P' THEN '(+)' ELSE '(-)' END AS op
    FROM PR_Configura5ta C (NOLOCK)
        LEFT JOIN PR_ProcessType PT (NOLOCK)
            ON PT.Company = C.Company
           AND PT.ProcessType = C.ProcessType
        LEFT JOIN PR_Concept CT (NOLOCK)
            ON CT.Company = C.Company
           AND CT.Concept = C.Concept
    WHERE C.Company = @cia
    ORDER BY
        CASE C.Type
            WHEN 'IN' THEN 1
            WHEN 'LI' THEN 2
            WHEN 'UT' THEN 3
            WHEN 'RE' THEN 4
            ELSE 9
        END,
        C.line;
END
GO
