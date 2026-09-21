/*
    Agrega dias anuales de vacaciones por trabajador (PR_Employee).
    Permite override respecto a PR_PayRollType.DiasVacaciones.
*/
IF OBJECT_ID(N'dbo.PR_Employee', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Employee', 'DiasVacaciones') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_Employee ADD DiasVacaciones INT NULL');
END
GO

/* Si ya existe la columna, no fuerza valor: se rellena por cliente (p.ej. desde PayRollType). */
GO
