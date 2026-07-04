/*
    Trabajadores elegibles para cálculo masivo multi-empresa.
    Resuelve PayRollType y ProcessType por Description en cada empresa.
    @companies: códigos separados por coma.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_calcularplanillas_masivo_web]
    @payroll_desc VARCHAR(200),
    @proceso_desc  VARCHAR(200),
    @period        VARCHAR(10),
    @cesados       CHAR(1),
    @companies     VARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    SET @proceso_desc = LTRIM(RTRIM(ISNULL(@proceso_desc, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 10);
    SET @companies = LTRIM(RTRIM(ISNULL(@companies, '')));
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    DECLARE @fecha_inicio_mes DATE;
    DECLARE @fecha_fin_mes DATE;
    DECLARE @period_ym CHAR(6);

    SET @period_ym = LEFT(@period, 6);
    IF LEN(@period_ym) = 6 AND @period_ym NOT LIKE '%[^0-9]%'
    BEGIN
        SET @fecha_inicio_mes = CONVERT(DATE, @period_ym + '01', 112);
        SET @fecha_fin_mes = EOMONTH(@fecha_inicio_mes);
    END

    DECLARE @empresas TABLE (
        company      VARCHAR(10) NOT NULL PRIMARY KEY,
        payrolltype  VARCHAR(20) NULL,
        processtype  VARCHAR(20) NULL
    );

    DECLARE @piece VARCHAR(10);
    DECLARE @pt VARCHAR(20);
    DECLARE @proc VARCHAR(20);

    IF @companies <> ''
    BEGIN
        DECLARE @work VARCHAR(500) = @companies + ',';
        DECLARE @pos INT;

        WHILE LEN(@work) > 0
        BEGIN
            SET @pos = CHARINDEX(',', @work);
            IF @pos = 0 BREAK;
            SET @piece = UPPER(LTRIM(RTRIM(LEFT(@work, @pos - 1))));
            SET @work = SUBSTRING(@work, @pos + 1, LEN(@work));
            SET @pt = NULL;
            SET @proc = NULL;

            IF @piece <> ''
            AND NOT EXISTS (SELECT 1 FROM @empresas e WHERE e.company = @piece)
            BEGIN
                SELECT TOP 1 @pt = PayRollType
                FROM PR_PayRollType (NOLOCK)
                WHERE Company = @piece
                  AND LTRIM(RTRIM(Description)) = @payroll_desc;

                IF @pt IS NOT NULL
                BEGIN
                    SELECT TOP 1 @proc = ptp.ProcessType
                    FROM PR_PayRollTypeProcess ptp (NOLOCK)
                        INNER JOIN PR_ProcessType pt2 (NOLOCK)
                            ON pt2.Company = ptp.Company
                           AND pt2.ProcessType = ptp.ProcessType
                    WHERE ptp.Company = @piece
                      AND ptp.PayRollType = @pt
                      AND LTRIM(RTRIM(pt2.Description)) = @proceso_desc;
                END

                IF @pt IS NOT NULL
               AND @proc IS NOT NULL
               AND EXISTS (
                    SELECT 1
                    FROM PR_ProcessControl PC (NOLOCK)
                    WHERE PC.Company = @piece
                      AND PC.PayRollType = @pt
                      AND PC.ProcessType = @proc
                      AND PC.PRPeriod = @period
                      AND PC.Status IN ('A', 'C', 'G')
               )
                    INSERT INTO @empresas (company, payrolltype, processtype)
                    VALUES (@piece, @pt, @proc);
            END
        END
    END

    SELECT
        e.company,
        ISNULL(sc.description, e.company) AS company_desc,
        e.payrolltype,
        e.processtype,
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS [name],
        PR_EMPLOYEE.PERSON AS person,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS entrydate,
        PR_EMPLOYEE.CEASEDATE AS ceasedate,
        EPR.XLastDate AS calculationdate
    FROM @empresas e
        INNER JOIN SY_Company sc (NOLOCK)
            ON sc.Company = e.company
        INNER JOIN PR_EMPLOYEE (NOLOCK)
            ON PR_EMPLOYEE.COMPANY = e.company
           AND PR_EMPLOYEE.PAYROLLTYPE = e.payrolltype
        INNER JOIN SY_PERSON (NOLOCK)
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_EmployeePayRoll EPR (NOLOCK)
            ON EPR.Person = PR_EMPLOYEE.Person
           AND EPR.Company = e.company
           AND EPR.PayRollType = e.payrolltype
           AND EPR.ProcessType = e.processtype
           AND LTRIM(RTRIM(EPR.PRPeriod)) = @period
    WHERE PR_EMPLOYEE.STATUS = 'N'
      AND (
            (
                @cesados = 'T'
                AND (
                    PR_EMPLOYEE.CEASEDATE IS NULL
                    OR @fecha_inicio_mes IS NULL
                    OR CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) >= @fecha_inicio_mes
                )
            )
            OR (
                @cesados = 'Y'
                AND @fecha_inicio_mes IS NOT NULL
                AND @fecha_fin_mes IS NOT NULL
                AND PR_EMPLOYEE.CEASEDATE IS NOT NULL
                AND CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) >= @fecha_inicio_mes
                AND CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) <= @fecha_fin_mes
            )
            OR (
                @cesados = 'N'
                AND PR_EMPLOYEE.CEASEDATE IS NULL
            )
      )
      AND (
            @fecha_fin_mes IS NULL
            OR CONVERT(DATE, ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE)) <= @fecha_fin_mes
      )
    ORDER BY e.company ASC, [name] ASC, person ASC;
END
GO
