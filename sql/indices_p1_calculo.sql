/*
  Índices P1 para el cálculo de planillas (filtros Company-first).
  Los PK heredados no empiezan por Company y no cubren estos filtros.
  Idempotente; aplica a cualquier BD cliente (con o sin fórmulas).
*/

IF OBJECT_ID('dbo.PR_EmployeePayRollConcept') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EPC_CiaPersonPeriod' AND object_id = OBJECT_ID('dbo.PR_EmployeePayRollConcept'))
    CREATE NONCLUSTERED INDEX IX_EPC_CiaPersonPeriod
    ON dbo.PR_EmployeePayRollConcept (Company, Person, PayRollType, ProcessType, PRPeriod);
GO

IF OBJECT_ID('dbo.PR_Concept') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Concept_CiaFormulaCode' AND object_id = OBJECT_ID('dbo.PR_Concept'))
    CREATE NONCLUSTERED INDEX IX_Concept_CiaFormulaCode
    ON dbo.PR_Concept (Company, FormulaCode)
    INCLUDE (Concept);
GO

IF OBJECT_ID('dbo.PR_FormulaHeader') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FH_CiaPayProc' AND object_id = OBJECT_ID('dbo.PR_FormulaHeader'))
    CREATE NONCLUSTERED INDEX IX_FH_CiaPayProc
    ON dbo.PR_FormulaHeader (Company, Payrolltype, Proccestype)
    INCLUDE (Concept, GrupoFormula, orden);
GO
