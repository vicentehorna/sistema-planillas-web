/*
    PR_Mapping2: conceptos de descuento de préstamo por tipo de proceso.
    Guarda el ID (PR_Concept.Concept), no el FormulaCode.

    Columnas:
      LoanConceptFinMes        — Fin de mes / mensual
      LoanConceptVacaciones    — Vacaciones
      LoanConceptUtilidades    — Utilidades
      LoanConceptGratificacion — Gratificación

    Solo estructura por ahora (sin UI ni cambio de SPs).
*/
IF COL_LENGTH('dbo.PR_Mapping2', 'LoanConceptFinMes') IS NULL
    ALTER TABLE dbo.PR_Mapping2 ADD LoanConceptFinMes VARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.PR_Mapping2', 'LoanConceptVacaciones') IS NULL
    ALTER TABLE dbo.PR_Mapping2 ADD LoanConceptVacaciones VARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.PR_Mapping2', 'LoanConceptUtilidades') IS NULL
    ALTER TABLE dbo.PR_Mapping2 ADD LoanConceptUtilidades VARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.PR_Mapping2', 'LoanConceptGratificacion') IS NULL
    ALTER TABLE dbo.PR_Mapping2 ADD LoanConceptGratificacion VARCHAR(20) NULL;
GO
