/*
    Detalle de préstamos y cuotas de un trabajador.
    Panel derecho — Control de Préstamos.
    Usado por: POST /api/prestamos/obtener

    Resultsets:
      1) Empleado (cabecera)
      2) Préstamos (PR_EmployeeLoan)
      3) Amortizaciones (PR_EmployeeLoanAmortization)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_obtener_trabajador_web]
    @company VARCHAR(4),
    @person  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    IF @company = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía y trabajador.', 16, 1);
        RETURN;
    END;

    /* 1) Empleado */
    SELECT
        emp.Person AS person,
        emp.Company AS company,
        emp.EmployeeCode AS codigo,
        LTRIM(RTRIM(
            ISNULL(p.LastName1, '') + ' ' +
            ISNULL(p.LastName2, '') + ' ' +
            ISNULL(p.Name1, '') + ' ' +
            ISNULL(p.Name2, '')
        )) AS nombre,
        p.DocumentNumber AS documento,
        ca.CurrentAccountCurrency AS moneda,
        ISNULL(ca.TotalLoan, 0) AS totalloan,
        ISNULL(ca.TotalPayed, 0) AS totalpayed,
        ISNULL(ca.TotalPending, 0) AS totalpending
    FROM PR_Employee emp (NOLOCK)
        INNER JOIN SY_Person p (NOLOCK)
            ON p.Person = emp.Person
        LEFT JOIN PR_EmployeeCurrentAccount ca (NOLOCK)
            ON ca.Person = emp.Person
           AND ca.Company = emp.Company
    WHERE emp.Company = @company
      AND emp.Person = @person;

    /* 2) Préstamos
       Status de cabecera: si está Anulado se respeta;
       si no, se deriva de cuotas (P si queda alguna pendiente; A si todas amortizadas).
       Motivo: el cálculo de planilla solo pone Status='A' en amortización, no en el préstamo. */
    SELECT
        el.Person AS person,
        el.Company AS company,
        el.Secuence AS secuence,
        el.LoanDate AS loandate,
        el.PRPeriod AS prperiod,
        el.LoadCurrency AS moneda,
        ISNULL(el.LoadAmount, 0) AS loadamount,
        ISNULL(el.NumberQuotes, 0) AS numberquotes,
        ISNULL(el.AMOUNTQUOTE, 0) AS amountquote,
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(el.Status, '')))) = 'N' THEN 'N'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeLoanAmortization ea (NOLOCK)
                WHERE ea.Company = el.Company
                  AND ea.Person = el.Person
                  AND ea.LOANSECUENCE = el.Secuence
                  AND UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))) = 'P'
            ) THEN 'P'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeLoanAmortization ea (NOLOCK)
                WHERE ea.Company = el.Company
                  AND ea.Person = el.Person
                  AND ea.LOANSECUENCE = el.Secuence
            ) THEN 'A'
            ELSE UPPER(LTRIM(RTRIM(ISNULL(el.Status, ''))))
        END AS status,
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(el.Status, '')))) = 'N' THEN 'Anulado'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeLoanAmortization ea (NOLOCK)
                WHERE ea.Company = el.Company
                  AND ea.Person = el.Person
                  AND ea.LOANSECUENCE = el.Secuence
                  AND UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))) = 'P'
            ) THEN 'Pendiente'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeLoanAmortization ea (NOLOCK)
                WHERE ea.Company = el.Company
                  AND ea.Person = el.Person
                  AND ea.LOANSECUENCE = el.Secuence
            ) THEN 'Amortizado'
            ELSE
                CASE UPPER(LTRIM(RTRIM(ISNULL(el.Status, ''))))
                    WHEN 'P' THEN 'Pendiente'
                    WHEN 'A' THEN 'Amortizado'
                    WHEN 'N' THEN 'Anulado'
                    ELSE LTRIM(RTRIM(ISNULL(el.Status, '')))
                END
        END AS status_texto,
        el.LOANCLASS AS loanclass,
        el.LoanType AS loantype,
        el.LoanReason AS loanreason,
        el.Reference AS reference,
        el.CostCenter AS costcenter,
        el.CostCenterCode AS costcentercode,
        ISNULL(el.RATEINTEREST, 0) AS rateinterest,
        el.XLastDate AS xlastdate
    FROM PR_EmployeeLoan el (NOLOCK)
    WHERE el.Company = @company
      AND el.Person = @person
    ORDER BY el.LoanDate DESC, el.Secuence DESC;

    /* 3) Amortizaciones / cuotas */
    SELECT
        ea.Person AS person,
        ea.Company AS company,
        ea.Secuence AS secuence,
        CONVERT(INT, ISNULL(ea.LOANSECUENCE, 0)) AS loansecuence,
        ea.PRperiod AS prperiod,
        ea.AmortizationCurrency AS moneda,
        ISNULL(ea.Amount, 0) AS amount,
        ISNULL(ea.INTEREST, 0) AS interest,
        ISNULL(ea.AMOUNTTOTAL, 0) AS amounttotal,
        ea.Status AS status,
        CASE UPPER(LTRIM(RTRIM(ISNULL(ea.Status, ''))))
            WHEN 'P' THEN 'Pendiente'
            WHEN 'A' THEN 'Amortizado'
            WHEN 'N' THEN 'Anulado'
            ELSE LTRIM(RTRIM(ISNULL(ea.Status, '')))
        END AS status_texto,
        LTRIM(RTRIM(ISNULL(ea.flagliquidation, ''))) AS flagliquidation,
        CASE UPPER(LTRIM(RTRIM(ISNULL(ea.flagliquidation, ''))))
            WHEN 'F' THEN 'Fin de Mes'
            WHEN 'G' THEN 'Gratificación'
            WHEN 'L' THEN 'Liquidación'
            WHEN 'Q' THEN 'Quincena'
            WHEN 'U' THEN 'Utilidades'
            WHEN 'N' THEN '—'
            WHEN '' THEN '—'
            ELSE LTRIM(RTRIM(ea.flagliquidation))
        END AS proceso_texto,
        ea.CostCenter AS costcenter,
        ea.CostCenterCode AS costcentercode,
        ea.comments AS comments,
        ea.XLastDate AS xlastdate
    FROM PR_EmployeeLoanAmortization ea (NOLOCK)
    WHERE ea.Company = @company
      AND ea.Person = @person
    ORDER BY
        CASE UPPER(LTRIM(RTRIM(ISNULL(ea.Status, ''))))
            WHEN 'P' THEN 1
            WHEN 'A' THEN 2
            ELSE 3
        END,
        ea.PRperiod DESC,
        ea.Secuence ASC;
END
GO
