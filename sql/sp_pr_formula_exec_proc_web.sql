/*
    Ejecuta procedimientos autorizados desde fórmulas tipo Código (K).
    Lista blanca: solo SPs registrados aquí pueden invocarse vía placeholder #S:...#.
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_formula_exec_proc_web
    @procname sysname,
    @nargs int = 0,
    @arg1 numeric(19, 4) = 0,
    @arg2 numeric(19, 4) = 0,
    @arg3 numeric(19, 4) = 0,
    @cia varchar(20),
    @period varchar(20),
    @payrolltype varchar(20),
    @processtype varchar(20),
    @person varchar(20),
    @result numeric(19, 4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @result = 0;

    DECLARE @p sysname = UPPER(LTRIM(RTRIM(ISNULL(@procname, ''))));
    SET @nargs = ISNULL(@nargs, 0);

    IF @p = 'SP_PR_REPORTETOTALQUINTAPERSONA'
    BEGIN
        IF OBJECT_ID('dbo.SP_PR_ReporteTotalQuintaPERSONA', 'P') IS NULL
            RETURN;

        IF EXISTS (
            SELECT 1
            FROM sys.parameters
            WHERE object_id = OBJECT_ID('dbo.SP_PR_ReporteTotalQuintaPERSONA')
              AND name = '@deducible'
        )
        BEGIN
            EXEC dbo.SP_PR_ReporteTotalQuintaPERSONA
                @cia, @period, @payrolltype, @processtype, @person,
                @arg1, @result OUTPUT;
        END
        ELSE
        BEGIN
            EXEC dbo.SP_PR_ReporteTotalQuintaPERSONA
                @cia, @period, @payrolltype, @processtype, @person,
                @result OUTPUT;
        END
        RETURN;
    END

    RAISERROR('Procedimiento no autorizado en formulador: %s', 16, 1, @procname);
END
GO
