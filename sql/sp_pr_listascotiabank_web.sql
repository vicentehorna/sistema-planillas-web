/*
    Listado de trabajadores elegibles para archivo Scotiabank (140 caracteres).
    Banco destino: ERP_Bank.Name LIKE '%SCOTIABANK%' (o salarybank con el mismo texto).
    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
    @todos_bancos: N = solo cuenta propia Scotiabank; Y = propia Scotiabank + interbancarios.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listascotiabank_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @cesados         CHAR(1),
    @todos_bancos    CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';

    ;WITH Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
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
        ) > 0
    )
    SELECT
        e.person,
        LTRIM(RTRIM(
            CASE
                WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                ELSE sp.DocumentNumber
            END
        )) AS dni,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        p.importe,
        pdt.PDT AS tipodoc,
        LTRIM(RTRIM(ISNULL(eb.Name, ISNULL(e.salarybank, '')))) AS banco
    FROM PR_Employee e
        INNER JOIN SY_Person sp ON sp.person = e.person
        INNER JOIN pr_mapping m ON m.company = e.company
        INNER JOIN Pagos p ON p.person = e.person
        LEFT JOIN SY_PersonDocumentType pdt
            ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        LEFT JOIN te_accounttype tat
            ON tat.accounttype = e.salaryaccounttype
        LEFT JOIN ERP_Bank eb
            ON eb.bank = e.salarybank
           AND eb.company = e.company
    WHERE e.company = @par_company
      AND e.payrolltype = @par_payrolltype
      AND (
            e.salarycurrency = @par_currency
         OR (@par_currency = 'EX' AND ISNULL(e.socialassistancecenter, '') <> '')
      )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ISNULL(m.collectionform, '') <> ''
      AND e.collectionform = m.collectionform
      AND (
            (
                @todos_bancos = 'N'
                AND (
                    UPPER(ISNULL(eb.Name, '')) LIKE '%SCOTIABANK%'
                 OR UPPER(ISNULL(e.salarybank, '')) LIKE '%SCOTIABANK%'
                )
                AND ISNULL(e.salaryaccount, '') <> ''
            )
         OR (
                @todos_bancos = 'Y'
                AND (
                    (
                        (
                            UPPER(ISNULL(eb.Name, '')) LIKE '%SCOTIABANK%'
                         OR UPPER(ISNULL(e.salarybank, '')) LIKE '%SCOTIABANK%'
                        )
                        AND ISNULL(e.salaryaccount, '') <> ''
                    )
                 OR (
                        UPPER(ISNULL(eb.Name, '')) NOT LIKE '%SCOTIABANK%'
                        AND UPPER(ISNULL(e.salarybank, '')) NOT LIKE '%SCOTIABANK%'
                        AND (
                            ISNULL(tat.abrev, '') = 'B'
                         OR UPPER(ISNULL(tat.description, '')) LIKE '%INTERBANCARIA%'
                        )
                        AND ISNULL(e.socialassistancenumber, '') <> ''
                    )
                )
            )
      )
      AND sp.status = 'A'
      AND (
            CASE
                WHEN e.status IS NULL THEN 'N'
                WHEN e.status = '' THEN 'N'
                WHEN e.status = 'N' THEN 'N'
                ELSE 'Y'
            END = 'N'
         OR e.ineffectivedate >= GETDATE()
      )
    ORDER BY nombre, dni;
END
GO
