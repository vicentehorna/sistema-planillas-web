/*
    Confirmación de recepción de boletas enviadas por correo (BD cliente).

    PR_DocumentPerson (Tipodocumento = 'BOL'):
      TokenConfirmacion      — UUID4 único por fila (se reutiliza en reenvíos)
      EstadoConfirmacion     — 0 Pendiente, 1 Confirmado (SÍ), 2 Observado (NO)
      FechaConfirmacion      — fecha/hora de la respuesta
      IpConfirmacion         — IP del cliente (X-Forwarded-For)
      UserAgentConfirmacion  — navegador del cliente

    El índice único filtrado exige QUOTED_IDENTIFIER / ANSI_NULLS ON en toda
    sesión o SP que haga INSERT/UPDATE/DELETE sobre PR_DocumentPerson.
    Revisar antes de aplicar:
      SELECT OBJECT_NAME(object_id) FROM sys.sql_modules
      WHERE definition LIKE '%PR_DocumentPerson%' AND uses_quoted_identifier = 0;
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.PR_DocumentPerson', 'TokenConfirmacion') IS NULL
    ALTER TABLE dbo.PR_DocumentPerson ADD TokenConfirmacion NVARCHAR(100) NULL;
GO
IF COL_LENGTH('dbo.PR_DocumentPerson', 'EstadoConfirmacion') IS NULL
    ALTER TABLE dbo.PR_DocumentPerson ADD EstadoConfirmacion SMALLINT NOT NULL
        CONSTRAINT DF_PR_DocumentPerson_EstadoConfirmacion DEFAULT (0);
GO
IF COL_LENGTH('dbo.PR_DocumentPerson', 'FechaConfirmacion') IS NULL
    ALTER TABLE dbo.PR_DocumentPerson ADD FechaConfirmacion DATETIME2(0) NULL;
GO
IF COL_LENGTH('dbo.PR_DocumentPerson', 'IpConfirmacion') IS NULL
    ALTER TABLE dbo.PR_DocumentPerson ADD IpConfirmacion NVARCHAR(45) NULL;
GO
IF COL_LENGTH('dbo.PR_DocumentPerson', 'UserAgentConfirmacion') IS NULL
    ALTER TABLE dbo.PR_DocumentPerson ADD UserAgentConfirmacion NVARCHAR(300) NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PR_DocumentPerson')
      AND name = 'UX_PR_DocumentPerson_TokenConfirmacion'
)
    CREATE UNIQUE NONCLUSTERED INDEX UX_PR_DocumentPerson_TokenConfirmacion
        ON dbo.PR_DocumentPerson (TokenConfirmacion)
        WHERE TokenConfirmacion IS NOT NULL;
GO
