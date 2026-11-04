/*
    Confirmación de recepción de boletas enviadas por correo (BD cliente).

    PR_DocumentPerson (Tipodocumento = 'BOL'):
      TokenConfirmacion      — UUID4 único por fila (se reutiliza en reenvíos)
      EstadoConfirmacion     — 0 Pendiente, 1 Confirmado (SÍ), 2 Observado (NO)
      FechaConfirmacion      — fecha/hora de la respuesta
      IpConfirmacion         — IP del cliente (X-Forwarded-For)
      UserAgentConfirmacion  — navegador del cliente

    IMPORTANTE — índice de TokenConfirmacion:
      Un UNIQUE FILTERED INDEX exige ANSI_NULLS / QUOTED_IDENTIFIER / etc. ON
      en toda sesión que haga INSERT/UPDATE/DELETE sobre PR_DocumentPerson.
      El cliente desktop (PowerBuilder / envío de boletas) no cumple esos SET
      y falla con error 1934. Por eso se usa índice NO único y SIN filtro;
      la unicidad del token la garantiza la app web (UUID4).
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
/* Si la columna ya existía sin DEFAULT, el desktop falla al INSERT sin EstadoConfirmacion. */
IF COL_LENGTH('dbo.PR_DocumentPerson', 'EstadoConfirmacion') IS NOT NULL
   AND NOT EXISTS (
        SELECT 1
        FROM sys.default_constraints dc
        WHERE dc.parent_object_id = OBJECT_ID('dbo.PR_DocumentPerson')
          AND dc.parent_column_id = COLUMNPROPERTY(
                OBJECT_ID('dbo.PR_DocumentPerson'), 'EstadoConfirmacion', 'ColumnId')
   )
    ALTER TABLE dbo.PR_DocumentPerson
        ADD CONSTRAINT DF_PR_DocumentPerson_EstadoConfirmacion DEFAULT (0) FOR EstadoConfirmacion;
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

/* Quitar índice filtrado legado (rompe INSERT del sistema antiguo). */
IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PR_DocumentPerson')
      AND name = 'UX_PR_DocumentPerson_TokenConfirmacion'
)
    DROP INDEX UX_PR_DocumentPerson_TokenConfirmacion ON dbo.PR_DocumentPerson;
GO

/* Índice de búsqueda por token (sin filtro / sin unique → compatible con desktop). */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.PR_DocumentPerson')
      AND name = 'IX_PR_DocumentPerson_TokenConfirmacion'
)
    CREATE NONCLUSTERED INDEX IX_PR_DocumentPerson_TokenConfirmacion
        ON dbo.PR_DocumentPerson (TokenConfirmacion);
GO
