/*
    Fórmulas modificadas en los últimos N días (todas las empresas).
    Fecha de cambio = mayor XLastDate entre PR_FormulaHeader y sus líneas PR_FormulaDetail.
    Una fila por empresa + concepto (agrupa planillas y procesos).
    @incluir_masivo = 0 omite los cambios hechos por procesos masivos (XLastUser = 'MASIVO').
*/
SET NOCOUNT ON;

DECLARE @dias INT = 7;
DECLARE @incluir_masivo BIT = 1;
DECLARE @desde DATETIME = DATEADD(DAY, -@dias, GETDATE());

;WITH cambios AS (
    SELECT FH.Company, FH.Concept, FH.XLastDate AS Fecha
    FROM PR_FormulaHeader FH (NOLOCK)
    WHERE FH.XLastDate >= @desde
      AND (@incluir_masivo = 1 OR ISNULL(FH.XLastUser, '') <> 'MASIVO')

    UNION ALL

    SELECT FH.Company, FH.Concept, FD.XLastDate
    FROM PR_FormulaDetail FD (NOLOCK)
    JOIN PR_FormulaHeader FH (NOLOCK)
      ON FH.FormulaHeader = FD.FormulaHeader
     AND FH.Company = FD.company
    WHERE FD.XLastDate >= @desde
      AND (@incluir_masivo = 1 OR ISNULL(FD.XLastUser, '') <> 'MASIVO')
)
SELECT
    ISNULL(SC.description, CB.Company)  AS EMPRESA,
    ISNULL(C.Description, CB.Concept)   AS CONCEPTO,
    C.FormulaCode                       AS NEMONICO,
    MAX(CB.Fecha)                       AS [FECHA ULTIMO CAMBIO]
FROM cambios CB
LEFT JOIN SY_Company SC (NOLOCK)
  ON SC.Company = CB.Company
LEFT JOIN PR_Concept C (NOLOCK)
  ON C.Concept = CB.Concept
 AND C.Company = CB.Company
GROUP BY
    ISNULL(SC.description, CB.Company),
    ISNULL(C.Description, CB.Concept),
    C.FormulaCode
ORDER BY [FECHA ULTIMO CAMBIO] DESC, EMPRESA, CONCEPTO;
