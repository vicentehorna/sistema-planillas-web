/*
    Periodos de planilla para Generar Voucher (agrupados por mes).
    id   = PRPeriod (YYYYMMDD) representativo del mes
    text = YYYY-MM
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_generar_voucher_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));

    ;WITH base AS (
        SELECT
            PC.PRPeriod AS period,
            LEFT(LTRIM(RTRIM(PC.PRPeriod)), 6) AS yyyymm,
            ROW_NUMBER() OVER (
                PARTITION BY LEFT(LTRIM(RTRIM(PC.PRPeriod)), 6)
                ORDER BY PC.PRPeriod DESC
            ) AS rn
        FROM PR_ProcessControl PC (NOLOCK)
        WHERE PC.Company = @cia
          AND PC.PayRollType = @payrolltype
          AND PC.ProcessType = @processtype
          AND PC.Status IN ('A', 'C', 'G')
          AND LEN(LTRIM(RTRIM(ISNULL(PC.PRPeriod, '')))) >= 6
    )
    SELECT
        period AS id,
        LEFT(yyyymm, 4) + '-' + RIGHT(yyyymm, 2) AS text
    FROM base
    WHERE rn = 1
    ORDER BY yyyymm DESC;
END
GO
