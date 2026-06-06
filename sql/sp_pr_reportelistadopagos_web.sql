/*
    Listado de pagos por trabajador (reporte RPR001 / Listado de pago).
    Usado por: POST /api/reportes/listado-pagos (reporte_listado_pagos.html).

    Filtros (mismos que Telecrédito, sin fecha de pago) + banco haberes opcional:
      @par_company, @par_payrolltype, @par_processtype, @par_period,
      @par_concept, @par_currency (LO/EX), @cesados, @salarybank (0 = todos).

    Columnas alineadas al DataWindow ReportePagos (PowerBuilder).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportelistadopagos_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @cesados         CHAR(1),
    @salarybank      VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@salarybank, '')) = '' SET @salarybank = '0';

    ;WITH Importes AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM PR_EmployeePayRollConcept epc
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) <> 0
    )
    SELECT
        e.EmployeeCode AS employeecode,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS nombre,
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN b_cts.Name
            ELSE b_sal.Name
        END AS banco,
        CASE
            WHEN CHARINDEX('TACAR', sc.Description) > 0 THEN ru_pay.Description
            ELSE ru_per.Description
        END AS obra,
        cc.Name AS costcenter,
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN e.CTSAccount
            ELSE e.SalaryAccount
        END AS cuenta,
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN e.CTSCurrency
            ELSE e.SalaryCurrency
        END AS moneda,
        i.importe
    FROM Importes i
        INNER JOIN PR_Employee e
            ON e.Person = i.person
           AND e.Company = @par_company
        INNER JOIN SY_Person sp
            ON sp.Person = e.Person
        INNER JOIN SY_Company sc
            ON sc.Company = e.Company
        INNER JOIN PR_ProcessType pt
            ON pt.ProcessType = @par_processtype
           AND pt.Company = @par_company
        LEFT JOIN PR_EmployeePayRoll epr
            ON epr.Company = e.Company
           AND epr.Person = e.Person
           AND epr.PayRollType = @par_payrolltype
           AND epr.ProcessType = @par_processtype
           AND epr.PRPeriod = @par_period
        LEFT JOIN SY_ReplicationUnit ru_pay
            ON ru_pay.ReplicationUnit = epr.ReplicationUnit
        LEFT JOIN SY_ReplicationUnit ru_per
            ON ru_per.ReplicationUnit = sp.ReplicationUnit
        LEFT JOIN AC_CostCenter cc
            ON cc.CostCenter = e.CostCenter
        LEFT JOIN ERP_Bank b_sal
            ON b_sal.Bank = e.SalaryBank
           AND b_sal.Company = e.Company
        LEFT JOIN ERP_Bank b_cts
            ON b_cts.Bank = e.CTSBank
           AND b_cts.Company = e.Company
    WHERE e.PayRollType = @par_payrolltype
      AND (@salarybank = '0' OR e.SalaryBank = @salarybank)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
    ORDER BY
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN b_cts.Name
            ELSE b_sal.Name
        END,
        nombre,
        e.EmployeeCode;
END
GO
