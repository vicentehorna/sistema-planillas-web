/*
    Documento opcional para TXT Telecrédito BCP (haberes / CTS / pago unidad).
    Si está vacío, los SP usan DocumentNumber.
    UI editable solo en hm_alamo; columna en todas las BD para SPs compartidos.
*/
IF COL_LENGTH('dbo.SY_Person', 'DocumentNumberBcp') IS NULL
BEGIN
    ALTER TABLE dbo.SY_Person ADD DocumentNumberBcp VARCHAR(15) NULL;
END
GO

UPDATE dbo.SY_Person
SET DocumentNumberBcp = LEFT(LTRIM(RTRIM(DocumentNumber)), 15)
WHERE DocumentNumberBcp IS NULL
  AND NULLIF(LTRIM(RTRIM(ISNULL(DocumentNumber, ''))), '') IS NOT NULL;
GO
