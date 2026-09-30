/*
    Devuelve el número de horas del periodo registrado en Tablas > Horas Trabajadas
    (dbo.PR_HorasTrabajadas, compañía principal BGT). Solo hm_garc.

    @period acepta YYYYMM o YYYYMMDD (PR_Period, p.ej. 20260909); se compara por año-mes.
    Si el periodo no está registrado devuelve 0.

    Uso directo:
        DECLARE @h numeric(19,4);
        EXEC dbo.sp_pr_obtenerhorastrabajadas @period = '20260909', @horas = @h OUTPUT;

    Uso en fórmulas (vía sp_pr_formula_exec_proc_web):
        LET HORAS = PROC("sp_pr_obtenerhorastrabajadas")          -- periodo del cálculo
        LET HORAS = PROC("sp_pr_obtenerhorastrabajadas", 202609)  -- periodo explícito
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_obtenerhorastrabajadas
    @period varchar(20),
    @horas numeric(19, 4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @horas = 0;

    DECLARE @p varchar(20) = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@period, ''))), '-', ''), '/', ''), ' ', '');
    IF LEN(@p) < 6 OR @p LIKE '%[^0-9]%'
        RETURN;

    SELECT TOP 1 @horas = CAST(NroHoras AS numeric(19, 4))
    FROM dbo.PR_HorasTrabajadas
    WHERE Company = 'BGT'
      AND LEFT(Period, 6) = LEFT(@p, 6)
    ORDER BY Period;

    SET @horas = ISNULL(@horas, 0);
END
GO
