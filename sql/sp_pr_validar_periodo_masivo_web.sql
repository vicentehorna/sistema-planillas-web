/*
    Valida que las empresas indicadas tengan el periodo abierto (Status A/C/G)
    para la planilla y proceso identificados por Description.
    @companies: códigos separados por coma, ej. BGT,SB01,SB02
    Una fila por empresa (sin duplicados por joins).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_validar_periodo_masivo_web]
    @payroll_desc VARCHAR(200),
    @proceso_desc  VARCHAR(200),
    @period        VARCHAR(10),
    @companies     VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    SET @proceso_desc = LTRIM(RTRIM(ISNULL(@proceso_desc, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 10);
    SET @companies = LTRIM(RTRIM(ISNULL(@companies, '')));

    DECLARE @empresas TABLE (company VARCHAR(10) NOT NULL PRIMARY KEY);

    IF @companies <> ''
    BEGIN
        DECLARE @work VARCHAR(500) = @companies + ',';
        DECLARE @pos INT;
        DECLARE @piece VARCHAR(10);

        WHILE LEN(@work) > 0
        BEGIN
            SET @pos = CHARINDEX(',', @work);
            IF @pos = 0 BREAK;
            SET @piece = UPPER(LTRIM(RTRIM(LEFT(@work, @pos - 1))));
            SET @work = SUBSTRING(@work, @pos + 1, LEN(@work));
            IF @piece <> ''
            AND NOT EXISTS (SELECT 1 FROM @empresas e WHERE e.company = @piece)
                INSERT INTO @empresas (company) VALUES (@piece);
        END
    END

    SELECT
        sc.Company AS company,
        ISNULL(sc.description, sc.Company) AS company_desc,
        pt_id.PayRollType AS payrolltype,
        pr_id.ProcessType AS processtype,
        CASE
            WHEN pt_id.PayRollType IS NULL THEN 'SIN_PLANILLA'
            WHEN pr_id.ProcessType IS NULL THEN 'SIN_PROCESO'
            WHEN pc_ok.PRPeriod IS NULL THEN 'SIN_PERIODO'
            ELSE 'OK'
        END AS estado,
        CASE
            WHEN pt_id.PayRollType IS NULL THEN 'No existe el tipo de planilla en la empresa.'
            WHEN pr_id.ProcessType IS NULL THEN 'No existe el proceso en la empresa.'
            WHEN pc_ok.PRPeriod IS NULL THEN 'El periodo no está abierto para esta empresa.'
            ELSE ''
        END AS mensaje
    FROM @empresas e
        INNER JOIN SY_Company sc (NOLOCK)
            ON sc.Company = e.company
           AND sc.status = 'A'
        OUTER APPLY (
            SELECT TOP 1 PayRollType
            FROM PR_PayRollType (NOLOCK)
            WHERE Company = sc.Company
              AND LTRIM(RTRIM(Description)) = @payroll_desc
        ) pt_id
        OUTER APPLY (
            SELECT TOP 1 ptp.ProcessType
            FROM PR_PayRollTypeProcess ptp (NOLOCK)
                INNER JOIN PR_ProcessType pt (NOLOCK)
                    ON pt.Company = ptp.Company
                   AND pt.ProcessType = ptp.ProcessType
            WHERE ptp.Company = sc.Company
              AND ptp.PayRollType = pt_id.PayRollType
              AND LTRIM(RTRIM(pt.Description)) = @proceso_desc
        ) pr_id
        OUTER APPLY (
            SELECT TOP 1 PC.PRPeriod
            FROM PR_ProcessControl PC (NOLOCK)
            WHERE PC.Company = sc.Company
              AND PC.PayRollType = pt_id.PayRollType
              AND PC.ProcessType = pr_id.ProcessType
              AND PC.PRPeriod = @period
              AND PC.Status IN ('A', 'C', 'G')
        ) pc_ok
    ORDER BY sc.Company ASC;
END
GO
