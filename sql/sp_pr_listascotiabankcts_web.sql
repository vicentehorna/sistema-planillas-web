/*
    Listado de trabajadores con CTS calculada para el archivo Scotiabank CTS.

    Importe: concepto PR_Mapping.CTSConcept del proceso ShortName 'CTS'.
    Banco destino: ERP_Bank.Name / CTSBank LIKE '%SCOTIABANK%'.
    Con @todos_bancos = 'Y' también entran cuentas CTS de otros bancos (abono 'I').
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listascotiabankcts_web]
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
            CASE
                WHEN UPPER(ISNULL(eb.Name, '')) LIKE '%SCOTIABANK%'
                  OR UPPER(ISNULL(e.CTSBank, '')) LIKE '%SCOTIABANK%'
                    THEN 'P'
                ELSE 'I'
            END AS tipo_abono,
            ISNULL(NULLIF(LTRIM(RTRIM(e.CTSCurrency)), ''), 'LO') AS moneda_cts,
            CAST(ROUND(p.importe, 2) AS DECIMAL(18, 2)) AS importe,
            CASE
                WHEN UPPER(ISNULL(eb.Name, '')) LIKE '%SCOTIABANK%'
                  OR UPPER(ISNULL(e.CTSBank, '')) LIKE '%SCOTIABANK%'
                    THEN 1
                ELSE 0
            END AS es_scotia
        FROM Pagos p
            INNER JOIN PR_Employee e
                ON e.Company = @par_company
               AND e.Person = p.Person
            INNER JOIN SY_Person sp
                ON sp.Person = p.Person
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
            WHEN ISNULL(cuenta, '') = '' THEN 'N'
            WHEN moneda_cts <> @par_currency THEN 'N'
            WHEN @todos_bancos = 'N' AND es_scotia = 0 THEN 'N'
            WHEN @todos_bancos = 'Y' AND ISNULL(banco, '') = '' THEN 'N'
            ELSE 'S'
        END AS elegible,
        CASE
            WHEN ISNULL(cuenta, '') = '' THEN 'Sin cuenta CTS'
            WHEN moneda_cts <> @par_currency THEN 'Moneda CTS distinta al filtro'
            WHEN @todos_bancos = 'N' AND es_scotia = 0 THEN 'Cuenta CTS en otro banco'
            WHEN @todos_bancos = 'Y' AND ISNULL(banco, '') = '' THEN 'Sin banco CTS'
            ELSE ''
        END AS motivo
    FROM Base
    ORDER BY nombre, person;
END
GO
