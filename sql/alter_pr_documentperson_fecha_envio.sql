/*
    Asegura columnas de envío de boletas en PR_DocumentPerson.
    Idempotente. Requerido por registrar_fecha_envio_boleta y
    sp_pr_reporteenvioboletas_web.
*/
SET NOCOUNT ON;

IF COL_LENGTH('dbo.PR_DocumentPerson', 'FechaEnvio') IS NULL
BEGIN
    ALTER TABLE dbo.PR_DocumentPerson ADD FechaEnvio DATETIME NULL;
END
GO

IF COL_LENGTH('dbo.PR_DocumentPerson', 'payrolltype') IS NULL
BEGIN
    ALTER TABLE dbo.PR_DocumentPerson ADD payrolltype VARCHAR(20) NULL;
END
GO

IF COL_LENGTH('dbo.PR_DocumentPerson', 'processtype') IS NULL
BEGIN
    ALTER TABLE dbo.PR_DocumentPerson ADD processtype VARCHAR(20) NULL;
END
GO
