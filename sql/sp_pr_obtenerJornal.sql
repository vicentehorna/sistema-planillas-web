/*
    Devuelve el jornal del cargo del trabajador (PR_Position.jornal).

    Busca PR_Employee.Position y lee PR_Position.jornal de la misma compañía.
    Sin cargo o sin jornal -> 0.

    Uso directo:
        DECLARE @j numeric(19,4);
        EXEC dbo.sp_pr_obtenerJornal @cia = 'BGT', @person = '12345678', @jornal = @j OUTPUT;

    Uso en fórmulas tipo Código/parser (vía sp_pr_formula_exec_proc_web):
        LET JORNAL = PROC("sp_pr_obtenerJornal")
        RESULT = JORNAL
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_obtenerJornal
    @cia    varchar(20),
    @person varchar(20),
    @jornal numeric(19, 4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @jornal = 0;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    IF @cia = '' OR @person = ''
        RETURN;

    SELECT @jornal = ISNULL(pos.jornal, 0)
    FROM dbo.PR_Employee e (NOLOCK)
        INNER JOIN dbo.PR_Position pos (NOLOCK)
            ON pos.Position = e.Position
           AND pos.Company = e.Company
    WHERE e.Company = @cia
      AND e.Person = @person;
END
GO
