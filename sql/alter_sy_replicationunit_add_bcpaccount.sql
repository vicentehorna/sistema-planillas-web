/*
    Asegura columna bcpAccount en SY_ReplicationUnit (Nro Cuenta BCP).
    Idempotente. Usado por maestro Unidades.
*/
IF OBJECT_ID('dbo.SY_ReplicationUnit', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_ReplicationUnit', 'bcpAccount') IS NULL
BEGIN
    ALTER TABLE dbo.SY_ReplicationUnit ADD bcpAccount VARCHAR(20) NULL;
END
GO
