/*
    Listado de trabajadores con CTS calculada para el archivo Continental / BBVA.

    Importe: concepto PR_Mapping.CTSConcept del proceso ShortName 'CTS'.
    Elegible si la cuenta CTS (PR_Employee.CTSBank / CTSAccount) es del banco
    PR_Mapping.continentalbank y la moneda CTS coincide. Con @todos_bancos = 'Y'
    también entran cuentas CTS de otros bancos (abono interbancario 'I').
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listacontinentalcts_web]
    @par_company     VARCHAR(10),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_currency    VARCHAR(2) = 'LO',
    @cesados         CHAR(1) = 'T',
    @repunit         VARCHAR(20) = '0',
    @todos_bancos    CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    SET @par_currency = UPPER(@par_currency);
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';

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
            LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) AS nombre,
            LTRIM(RTRIM(ISNULL(eb.Name, ISNULL(e.CTSBank, '')))) AS banco,
            REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', '') AS cuenta,
            CASE WHEN e.CTSBank = m.continentalbank THEN 'P' ELSE 'I' END AS tipo_abono,
            ISNULL(NULLIF(LTRIM(RTRIM(e.CTSCurrency)), ''), 'LO') AS moneda_cts,
            CAST(ROUND(p.importe, 2) AS DECIMAL(18, 2)) AS importe,
            LTRIM(RTRIM(ISNULL(m.continentalbank, ''))) AS banco_bbva,
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
        nombre,
        banco,
        cuenta,
        tipo_abono,
        moneda_cts,
        importe,
        CASE
            WHEN banco_bbva = '' THEN 'N'
            WHEN banco_cts = '' THEN 'N'
            WHEN cuenta = '' THEN 'N'
            WHEN moneda_cts <> @par_currency THEN 'N'
            WHEN @todos_bancos = 'N' AND banco_cts <> banco_bbva THEN 'N'
            ELSE 'S'
        END AS elegible,
        CASE
            WHEN banco_bbva = '' THEN 'BBVA no configurado (PR_Mapping.continentalbank)'
            WHEN banco_cts = '' THEN 'Sin banco CTS'
            WHEN cuenta = '' THEN 'Sin número de cuenta CTS'
            WHEN moneda_cts <> @par_currency THEN 'Cuenta CTS en otra moneda (' + moneda_cts + ')'
            WHEN @todos_bancos = 'N' AND banco_cts <> banco_bbva THEN 'Cuenta CTS en otro banco'
            ELSE ''
        END AS motivo
    FROM Base
    ORDER BY nombre, person;
END
GO
