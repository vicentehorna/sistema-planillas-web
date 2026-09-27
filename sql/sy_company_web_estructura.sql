/*
    Maestro de Empresas (web): ajustes de estructura en SY_Company.
    - Description -> VARCHAR(255)
    - Auditoría de creación: XCreateUser / XCreateDate
    Idempotente.
*/
SET NOCOUNT ON;

IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SY_Company')
      AND name = 'Description'
      AND max_length < 255
)
    ALTER TABLE dbo.SY_Company ALTER COLUMN Description VARCHAR(255) NULL;
GO

IF COL_LENGTH('dbo.SY_Company', 'XCreateUser') IS NULL
    ALTER TABLE dbo.SY_Company ADD XCreateUser VARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.SY_Company', 'XCreateDate') IS NULL
    ALTER TABLE dbo.SY_Company ADD XCreateDate DATETIME NULL;
GO

DECLARE @vista SYSNAME;
DECLARE cur_vistas CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
    FROM sys.sql_expression_dependencies d
        INNER JOIN sys.objects o ON o.object_id = d.referencing_id
        INNER JOIN sys.sql_modules m ON m.object_id = o.object_id
    WHERE d.referenced_id = OBJECT_ID('dbo.SY_Company')
      AND o.type = 'V'
      AND m.is_schema_bound = 0;
OPEN cur_vistas;
FETCH NEXT FROM cur_vistas INTO @vista;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sp_refreshview @vista;
    END TRY
    BEGIN CATCH
        PRINT 'sp_refreshview ' + @vista + ': ' + ERROR_MESSAGE();
    END CATCH;
    FETCH NEXT FROM cur_vistas INTO @vista;
END;
CLOSE cur_vistas;
DEALLOCATE cur_vistas;
GO
