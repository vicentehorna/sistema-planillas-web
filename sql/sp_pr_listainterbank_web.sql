/*
    Listado de trabajadores elegibles para archivo Interbank (pago de haberes).
    Usa pr_mapping.interbankbank (no creditobank).

    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
    @accountprofile: '' o '0' = todos; otro valor filtra PR_Employee.AccountProfile.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listainterbank_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @cesados         CHAR(1),
    @accountprofile  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    SET @accountprofile = LTRIM(RTRIM(ISNULL(@accountprofile, '')));
    IF @accountprofile = '0' SET @accountprofile = '';

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
        t.pdt AS tipodoc
    FROM PR_Employee e
        INNER JOIN SY_Person sp
            ON sp.person = e.person
        INNER JOIN pr_mapping m
            ON m.company = e.company
        INNER JOIN Pagos p
            ON p.person = e.person
        LEFT JOIN SY_PersonDocumentType t
            ON sp.EmployeeDocumentType = t.PersonDocumentType
    WHERE e.company = @par_company
      AND e.payrolltype = @par_payrolltype
      AND (
            @accountprofile = ''
            OR LTRIM(RTRIM(ISNULL(e.AccountProfile, ''))) = @accountprofile
          )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ISNULL(e.salaryaccount, '') <> ''
      AND ISNULL(m.interbankbank, '') <> ''
      AND e.salarybank = m.interbankbank
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
