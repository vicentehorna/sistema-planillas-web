/*
    Divisor fijo para líneas Promedio Vac (tipo M) y Promedio Grati (tipo H).
    Si > 0, la suma del rango se divide entre este valor.
    Si NULL o 0, se divide entre meses del rango (ajustado por ingreso/reingreso).
*/
IF OBJECT_ID(N'dbo.PR_FormulaDetail', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_FormulaDetail', 'Divisor') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_FormulaDetail ADD Divisor NUMERIC(19, 4) NULL');
END
GO
