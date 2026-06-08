/*
    Periodos configurados para apertura (PR_Period).
    Usado por: GET /api/aperturar-periodos/periodos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_apertura_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        LTRIM(RTRIM(p.PRPeriod)) AS prperiod,
        CASE
            WHEN LEN(LTRIM(RTRIM(p.PRPeriod))) >= 8
                THEN STUFF(STUFF(LTRIM(RTRIM(p.PRPeriod)), 5, 0, '-'), 8, 0, '-')
            WHEN LEN(LTRIM(RTRIM(p.PRPeriod))) >= 6
                THEN STUFF(LTRIM(RTRIM(p.PRPeriod)), 5, 0, '-')
            ELSE LTRIM(RTRIM(p.PRPeriod))
        END AS description
    FROM PR_Period p WITH (NOLOCK)
    WHERE p.Company = @cia
      AND p.PayRollType = @payrolltype
    ORDER BY p.PRPeriod DESC;
END
GO
