/*
    Código de la siguiente empresa (SY_Company.Company), misma regla del sistema anterior:
      - Toma el mayor correlativo de los códigos SBnn y Snnn y le suma 1.
      - Hasta 99  → 'SB' + 2 dígitos (SB01 … SB99).
      - Desde 100 → 'S'  + 3 dígitos (S100 … S999).
    Si el código calculado ya existe, avanza al siguiente libre.

    Usado por: GET /api/empresas/siguiente-codigo y sp_pr_registrarempresa_web.
*/
CREATE OR ALTER FUNCTION [dbo].[fn_pr_siguientecodigoempresa_web] ()
RETURNS VARCHAR(4)
AS
BEGIN
    DECLARE @n INT, @codigo VARCHAR(4);

    SELECT @n = MAX(x.num)
    FROM (
        SELECT CASE
                   WHEN LTRIM(RTRIM(Company)) LIKE 'SB[0-9][0-9]' THEN CAST(SUBSTRING(LTRIM(RTRIM(Company)), 3, 2) AS INT)
                   WHEN LTRIM(RTRIM(Company)) LIKE 'S[0-9][0-9][0-9]' THEN CAST(SUBSTRING(LTRIM(RTRIM(Company)), 2, 3) AS INT)
               END AS num
        FROM dbo.SY_Company
    ) x;

    SET @n = ISNULL(@n, 0) + 1;

    WHILE @n <= 999
    BEGIN
        SET @codigo = CASE
                          WHEN @n <= 99 THEN 'SB' + RIGHT('0' + CAST(@n AS VARCHAR(3)), 2)
                          ELSE 'S' + RIGHT('00' + CAST(@n AS VARCHAR(3)), 3)
                      END;
        IF NOT EXISTS (SELECT 1 FROM dbo.SY_Company WHERE Company = @codigo)
            RETURN @codigo;
        SET @n = @n + 1;
    END;

    RETURN NULL;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_pr_siguientecodigoempresa_web]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT dbo.fn_pr_siguientecodigoempresa_web() AS company;
END
GO
