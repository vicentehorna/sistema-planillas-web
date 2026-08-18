/*
    Agrega PR_Position.Status (A = Activo, I = Inactivo).
    Existentes quedan Activos.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.PR_Position', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.PR_Position', N'Status') IS NULL
BEGIN
    ALTER TABLE dbo.PR_Position ADD Status CHAR(1) NULL;
END
GO

IF OBJECT_ID(N'dbo.PR_Position', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.PR_Position', N'Status') IS NOT NULL
BEGIN
    UPDATE dbo.PR_Position
    SET Status = 'A'
    WHERE Status IS NULL
       OR LTRIM(RTRIM(Status)) = '';
END
GO
