SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    Listado de trabajadores con CTS calculada (proceso ShortName 'CTS', concepto
    PR_Mapping.CTSConcept) para el archivo Telecrédito CTS del BCP.

    Devuelve todos los trabajadores con CTS > 0 en el periodo; elegible = 'S' solo si
    la cuenta CTS del trabajador (PR_Employee.CTSBank/CTSAccount) es del banco
    PR_Mapping.CreditoBank (BCP) y su moneda CTS coincide con @par_currency.
    Los no elegibles traen el motivo.

    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
    @repunit: '0' = todas las unidades; otro valor filtra SY_Person.ReplicationUnit.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listatelecreditocts_web]
    @par_company     VARCHAR(10),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_currency    VARCHAR(2) = 'LO',
    @cesados         CHAR(1) = 'T',
    @repunit         VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    SET @par_currency = UPPER(@par_currency);
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';

    ;WITH Pagos AS (
        SELECT
            epc.Person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.ConceptValueEx, 0)
                    ELSE ISNULL(epc.ConceptValueLo, 0)
                END
            ) AS importe
        FROM PR_EmployeePayRollConcept epc
            INNER JOIN PR_Mapping m
                ON m.Company = epc.Company
               AND m.CTSConcept = epc.Concept
            INNER JOIN PR_ProcessType pt
                ON pt.Company = epc.Company
               AND pt.ProcessType = epc.ProcessType
               AND pt.ShortName = 'CTS'
        WHERE epc.Company = @par_company
          AND epc.PayRollType = @par_payrolltype
          AND epc.PRPeriod = @par_period
        GROUP BY epc.Person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.ConceptValueEx, 0)
                ELSE ISNULL(epc.ConceptValueLo, 0)
            END
        ) > 0
    ),
    Base AS (
        SELECT
            p.Person AS person,
            LTRIM(RTRIM(
                CASE
                    WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                    ELSE sp.DocumentNumber
                END
            )) AS dni,
            LTRIM(RTRIM(ISNULL(t.PDT, ''))) AS tipodoc,
            CASE
                WHEN ISNULL(t.PDT, '') IN ('01', '1') THEN '1'
                WHEN ISNULL(t.PDT, '') IN ('03', '04', '3', '4') THEN '3'
                WHEN ISNULL(t.PDT, '') IN ('06', '07') THEN '4'
                ELSE '1'
            END AS tipodoc_bcp,
            LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) AS nombre,
            LTRIM(RTRIM(ISNULL(eb.Name, ISNULL(e.CTSBank, '')))) AS banco,
            REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', '') AS cuenta,
            CASE WHEN ISNULL(tat.abrev, '') = 'C' THEN 'C' ELSE 'A' END AS tipocuenta,
            ISNULL(NULLIF(LTRIM(RTRIM(e.CTSCurrency)), ''), 'LO') AS moneda_cts,
            CAST(ROUND(p.importe, 2) AS DECIMAL(18, 2)) AS importe,
            LTRIM(RTRIM(ISNULL(m.CreditoBank, ''))) AS banco_bcp,
            LTRIM(RTRIM(ISNULL(e.CTSBank, ''))) AS banco_cts
        FROM Pagos p
            INNER JOIN PR_Employee e
                ON e.Company = @par_company
               AND e.Person = p.Person
            INNER JOIN SY_Person sp
                ON sp.Person = p.Person
            INNER JOIN PR_Mapping m
                ON m.Company = @par_company
            LEFT JOIN SY_PersonDocumentType t
                ON t.PersonDocumentType = sp.EmployeeDocumentType
            LEFT JOIN TE_AccountType tat
                ON tat.AccountType = e.CTSAccountType
            LEFT JOIN ERP_Bank eb
                ON eb.Bank = e.CTSBank
               AND eb.Company = e.Company
        WHERE (@repunit = '0' OR sp.ReplicationUnit = @repunit)
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND e.CeaseDate IS NULL)
          )
    )
    SELECT
        person,
        dni,
        tipodoc,
        tipodoc_bcp,
        nombre,
        banco,
        cuenta,
        tipocuenta,
        moneda_cts,
        importe,
        CASE
            WHEN banco_bcp = '' THEN 'N'
            WHEN banco_cts <> banco_bcp THEN 'N'
            WHEN cuenta = '' THEN 'N'
            WHEN moneda_cts <> @par_currency THEN 'N'
            ELSE 'S'
        END AS elegible,
        CASE
            WHEN banco_bcp = '' THEN 'BCP no configurado (PR_Mapping.CreditoBank)'
            WHEN banco_cts = '' THEN 'Sin banco CTS'
            WHEN banco_cts <> banco_bcp THEN 'Cuenta CTS en otro banco'
            WHEN cuenta = '' THEN 'Sin número de cuenta CTS'
            WHEN moneda_cts <> @par_currency THEN 'Cuenta CTS en otra moneda (' + moneda_cts + ')'
            ELSE ''
        END AS motivo
    FROM Base
    ORDER BY nombre, person;
END
GO
