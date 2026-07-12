/*
    Agrega campo de texto Nacionalidad en SY_Person.
    Usado por: maestro de trabajadores / datos generales (web).
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'SY_Person'
      AND c.name = 'Nacionalidad'
)
BEGIN
    ALTER TABLE dbo.SY_Person
        ADD Nacionalidad VARCHAR(100) NULL;
END
GO
