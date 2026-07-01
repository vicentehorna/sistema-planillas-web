/*
    Elimina un periodo de planilla (PR_Period).
    Usado por: POST /api/tipos-planilla/periodos/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarperiodo_payrolltype_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20),
    @prperiod    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @prperiod_norm VARCHAR(10);

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @prperiod_norm = REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@prperiod, ''))), '-', ''), '/', '');

    IF @company = '' OR @payrolltype = '' OR @prperiod_norm = ''
    BEGIN
        RAISERROR('Indique compañía, tipo de planilla y periodo.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Period (NOLOCK)
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND PRPeriod = @prperiod_norm
    )
    BEGIN
        RAISERROR('Periodo no encontrado.', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_Period
    WHERE Company = @company
      AND PayRollType = @payrolltype
      AND PRPeriod = @prperiod_norm;

    SELECT
        @prperiod_norm AS prperiod,
        'Periodo eliminado correctamente.' AS mensaje;
END
GO
