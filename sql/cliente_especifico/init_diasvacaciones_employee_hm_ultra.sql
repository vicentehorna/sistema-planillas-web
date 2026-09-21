/*
    hm_ultra: rellena PR_Employee.DiasVacaciones desde PR_PayRollType.
    Idempotente: actualiza todos los trabajadores con el valor de su planilla.
*/
IF OBJECT_ID(N'dbo.PR_Employee', N'U') IS NULL
   OR COL_LENGTH('dbo.PR_Employee', 'DiasVacaciones') IS NULL
BEGIN
    RAISERROR('Falta columna PR_Employee.DiasVacaciones. Ejecute alter_pr_employee_add_diasvacaciones.sql primero.', 16, 1);
    RETURN;
END
GO

UPDATE e
SET e.DiasVacaciones = ISNULL(pt.DiasVacaciones, 30),
    e.XLastUser = 'INIT_DIASVAC',
    e.XLastDate = GETDATE()
FROM dbo.PR_Employee e
LEFT JOIN dbo.PR_PayRollType pt
    ON pt.Company = e.Company
   AND pt.PayRollType = e.PayRollType;
GO

/* Sin planilla o sin maestro: forzar 30 */
UPDATE dbo.PR_Employee
SET DiasVacaciones = 30,
    XLastUser = 'INIT_DIASVAC',
    XLastDate = GETDATE()
WHERE DiasVacaciones IS NULL
   OR DiasVacaciones <= 0;
GO
