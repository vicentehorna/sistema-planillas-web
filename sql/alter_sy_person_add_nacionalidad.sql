/*
    Agrega campo de texto Nacionalidad en SY_Person.
    Usado por: maestro de trabajadores / datos generales (web).
*/
IF OBJECT_ID(N'dbo.SY_Person', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Person', 'Nacionalidad') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Person ADD Nacionalidad VARCHAR(100) NULL');
END
GO
