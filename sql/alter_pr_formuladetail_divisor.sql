/*
    Divisor fijo para líneas Promedio Vac (tipo M) y Promedio Grati (tipo H).
    Si > 0, la suma del rango se divide entre este valor.
    Si NULL o 0, se divide entre meses del rango (ajustado por ingreso/reingreso).
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.PR_FormulaDetail')
      AND name = 'Divisor'
)
BEGIN
    ALTER TABLE dbo.PR_FormulaDetail
        ADD Divisor NUMERIC(19, 4) NULL;
END
GO
