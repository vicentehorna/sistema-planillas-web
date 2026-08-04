/*
    Amplía PR_Position.Description (antes varchar(50) truncaba cargos largos)
    y sincroniza Description desde name cuando name es más completo.
*/
SET NOCOUNT ON;

IF EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo'
      AND TABLE_NAME = 'PR_Position'
      AND COLUMN_NAME = 'Description'
      AND CHARACTER_MAXIMUM_LENGTH IS NOT NULL
      AND CHARACTER_MAXIMUM_LENGTH < 255
)
BEGIN
    ALTER TABLE dbo.PR_Position ALTER COLUMN Description VARCHAR(255) NULL;
END
GO

UPDATE dbo.PR_Position
SET Description = LEFT(LTRIM(RTRIM(name)), 255)
WHERE NULLIF(LTRIM(RTRIM(name)), '') IS NOT NULL
  AND (
        Description IS NULL
     OR LTRIM(RTRIM(Description)) = ''
     OR LEN(LTRIM(RTRIM(ISNULL(name, '')))) > LEN(LTRIM(RTRIM(ISNULL(Description, ''))))
  );
GO
