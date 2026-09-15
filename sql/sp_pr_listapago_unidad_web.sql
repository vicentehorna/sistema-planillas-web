/*
    Listado multi-compañía de trabajadores para Pago por Unidad (hm_alamo).
    Resuelve planilla/proceso por Description (patrón consolidada).
    Concepto: code, Description o FormulaCode (p.ej. NETO).
    Filtra personas cuya SY_Person.ReplicationUnit está en #PagoUnidadUnidades
    (si la temp no existe o está vacía → todas las unidades con bcpAccount).

    Columnas: unidad, empresa, company, neto, codigo (DNI), nombre, person, tipodoc, banco.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listapago_unidad_web]
    @payroll_desc   VARCHAR(100),
    @proceso_desc   VARCHAR(100),
    @par_period     VARCHAR(8),
    @par_concept    VARCHAR(40),
    @par_currency   VARCHAR(2) = 'LO',
    @cesados        CHAR(1) = 'T',
    @todos_bancos   CHAR(1) = 'N',
    @par_paydate    DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    SET @proceso_desc = LTRIM(RTRIM(ISNULL(@proceso_desc, '')));
    SET @par_period = LTRIM(RTRIM(ISNULL(@par_period, '')));
    SET @par_concept = LTRIM(RTRIM(ISNULL(@par_concept, '')));
    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();

    IF @payroll_desc = '' OR @proceso_desc = '' OR @par_period = '' OR @par_concept = ''
    BEGIN
        RAISERROR('Indique tipo planilla, proceso, periodo y concepto.', 16, 1);
        RETURN;
    END;

    IF OBJECT_ID('tempdb..#UnidadesBcp') IS NOT NULL DROP TABLE #UnidadesBcp;
    CREATE TABLE #UnidadesBcp (replicationunit VARCHAR(20) NOT NULL PRIMARY KEY);

    /*
        Requiere #PagoUnidadUnidades creada por la app (puede ir vacía).
        Vacía ⇒ todas las unidades con bcpAccount.
    */
    IF NOT EXISTS (SELECT 1 FROM #PagoUnidadUnidades)
    BEGIN
        INSERT INTO #UnidadesBcp (replicationunit)
        SELECT LTRIM(RTRIM(ru.ReplicationUnit))
        FROM SY_ReplicationUnit ru (NOLOCK)
        WHERE NULLIF(LTRIM(RTRIM(ISNULL(ru.bcpAccount, ''))), '') IS NOT NULL;
    END
    ELSE
    BEGIN
        INSERT INTO #UnidadesBcp (replicationunit)
        SELECT DISTINCT LTRIM(RTRIM(u.replicationunit))
        FROM #PagoUnidadUnidades u
        INNER JOIN SY_ReplicationUnit ru (NOLOCK)
            ON ru.ReplicationUnit = LTRIM(RTRIM(u.replicationunit))
        WHERE NULLIF(LTRIM(RTRIM(ISNULL(ru.bcpAccount, ''))), '') IS NOT NULL
          AND LTRIM(RTRIM(ISNULL(u.replicationunit, ''))) <> '';
    END;

    ;WITH Pagos AS (
        SELECT
            epc.company,
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc (NOLOCK)
            INNER JOIN PR_PayRollType pt (NOLOCK)
                ON pt.Company = epc.Company
               AND pt.PayRollType = epc.PayRollType
               AND LTRIM(RTRIM(ISNULL(pt.Description, ''))) = @payroll_desc
            INNER JOIN PR_ProcessType prt (NOLOCK)
                ON prt.Company = epc.Company
               AND prt.ProcessType = epc.ProcessType
               AND LTRIM(RTRIM(ISNULL(prt.Description, ''))) = @proceso_desc
            INNER JOIN PR_Concept pc (NOLOCK)
                ON pc.Company = epc.Company
               AND pc.Concept = epc.Concept
               AND (
                    LTRIM(RTRIM(ISNULL(pc.Concept, ''))) = @par_concept
                 OR LTRIM(RTRIM(ISNULL(pc.Description, ''))) = @par_concept
                 OR LTRIM(RTRIM(ISNULL(pc.FormulaCode, ''))) = @par_concept
               )
        WHERE epc.prperiod = @par_period
        GROUP BY epc.company, epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    )
    SELECT
        LTRIM(RTRIM(ISNULL(sp.ReplicationUnit, ''))) AS unidad,
        LTRIM(RTRIM(ISNULL(sc.Description, e.company))) AS empresa,
        e.company,
        p.importe AS neto,
        LTRIM(RTRIM(
            CASE
                WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                ELSE sp.DocumentNumber
            END
        )) AS codigo,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        e.person,
        LTRIM(RTRIM(ISNULL(t.pdt, ''))) AS tipodoc,
        LTRIM(RTRIM(ISNULL(eb.Name, ISNULL(e.salarybank, '')))) AS banco
    FROM PR_Employee e (NOLOCK)
        INNER JOIN SY_Person sp (NOLOCK)
            ON sp.person = e.person
        INNER JOIN #UnidadesBcp ub
            ON ub.replicationunit = LTRIM(RTRIM(ISNULL(sp.ReplicationUnit, '')))
        INNER JOIN pr_mapping m (NOLOCK)
            ON m.company = e.company
        INNER JOIN Pagos p
            ON p.person = e.person
           AND p.company = e.company
        INNER JOIN PR_PayRollType pt2 (NOLOCK)
            ON pt2.Company = e.Company
           AND pt2.PayRollType = e.PayRollType
           AND LTRIM(RTRIM(ISNULL(pt2.Description, ''))) = @payroll_desc
        LEFT JOIN SY_Company sc (NOLOCK)
            ON sc.Company = e.Company
        LEFT JOIN SY_PersonDocumentType t (NOLOCK)
            ON sp.EmployeeDocumentType = t.PersonDocumentType
        LEFT JOIN te_accounttype tat (NOLOCK)
            ON tat.accounttype = e.salaryaccounttype
        LEFT JOIN ERP_Bank eb (NOLOCK)
            ON eb.bank = e.salarybank
           AND eb.company = e.company
    WHERE ISNULL(m.creditobank, '') <> ''
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND (
            (
                @todos_bancos = 'N'
                AND e.salarybank = m.creditobank
                AND ISNULL(e.salaryaccount, '') <> ''
            )
         OR (
                @todos_bancos = 'Y'
                AND (
                    (
                        e.salarybank = m.creditobank
                        AND ISNULL(e.salaryaccount, '') <> ''
                        AND NOT (
                            ISNULL(tat.abrev, '') = 'B'
                         OR UPPER(ISNULL(tat.description, '')) LIKE '%INTERBANCARIA%'
                        )
                    )
                 OR (
                        (
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
    ORDER BY unidad, empresa, nombre, codigo;
END
GO
