/*
    Genera líneas de detalle del archivo BANBIF / BXIE (213 caracteres por registro).
    No incluye cabecera (igual que el sistema PowerBuilder anterior).
    Requiere #BanbifPersonas (person) cargada por la app web.
    Banco destino: pr_mapping.banbifbank.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_banbif_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @todos_bancos    CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';

    IF OBJECT_ID('tempdb..#BanbifPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #BanbifPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @collectionform VARCHAR(20);
    DECLARE @banbifbank     VARCHAR(20);
    DECLARE @tipo_moneda    CHAR(1);

    SELECT @collectionform = LTRIM(RTRIM(ISNULL(m.collectionform, ''))),
           @banbifbank = LTRIM(RTRIM(ISNULL(m.banbifbank, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @collectionform = ''
    BEGIN
        RAISERROR('Configure la forma de pago (CollectionForm) en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    IF @banbifbank = ''
    BEGIN
        RAISERROR('Configure BanbifBank en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SET @tipo_moneda = CASE WHEN @par_currency = 'EX' THEN '2' ELSE '1' END;

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #BanbifPersonas tp
        WHERE LTRIM(RTRIM(ISNULL(tp.person, ''))) <> ''
    ),
    Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
            INNER JOIN PersonasSel ps ON ps.person = epc.person
            INNER JOIN PR_Employee emp
                ON emp.person = epc.person
               AND emp.company = epc.company
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
          AND emp.collectionform = @collectionform
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    ),
    DetalleBase AS (
        SELECT
            e.person,
            CASE
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4') THEN '3'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN '4'
                ELSE ' '
            END AS tipo_doc_txt,
            LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(ISNULL(sp.lastname1, ''))) AS lastname1,
            LTRIM(RTRIM(ISNULL(sp.lastname2, ''))) AS lastname2,
            LTRIM(RTRIM(
                LTRIM(RTRIM(ISNULL(sp.name1, ''))) + ' ' +
                LTRIM(RTRIM(ISNULL(sp.name2, '')))
            )) AS nombres,
            LEFT(
                CASE
                    WHEN LEN(LTRIM(RTRIM(ISNULL(eb.PDT, '')))) = 2
                        THEN '0' + LTRIM(RTRIM(eb.PDT))
                    ELSE LEFT(LTRIM(RTRIM(ISNULL(eb.PDT, ''))) + REPLICATE(' ', 3), 3)
                END,
                3
            ) AS codbank,
            LEFT(
                LTRIM(RTRIM(
                    CASE
                        WHEN @todos_bancos = 'Y' THEN ISNULL(e.socialassistancenumber, '')
                        WHEN @par_currency = 'EX' THEN ISNULL(e.socialassistancecenter, '')
                        ELSE ISNULL(e.salaryaccount, '')
                    END
                )) + REPLICATE(' ', 20),
                20
            ) AS cuenta_empleado,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
            LEFT JOIN ERP_Bank eb
                ON eb.bank = e.salarybank
               AND eb.company = e.company
            LEFT JOIN te_accounttype tat
                ON tat.accounttype = e.salaryaccounttype
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND (
                e.salarycurrency = @par_currency
             OR (@par_currency = 'EX' AND ISNULL(e.socialassistancecenter, '') <> '')
          )
          AND ISNULL(m.banbifbank, '') <> ''
          AND e.collectionform = @collectionform
          AND (
                (@todos_bancos = 'N' AND e.salarybank = m.banbifbank)
             OR (
                    @todos_bancos = 'Y'
                    AND e.salarybank <> m.banbifbank
                    AND (
                        ISNULL(tat.abrev, '') = 'B'
                     OR UPPER(ISNULL(tat.description, '')) LIKE '%INTERBANCARIA%'
                    )
                    AND ISNULL(e.socialassistancenumber, '') <> ''
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
    ),
    Numerado AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                ORDER BY lastname1, lastname2, nombres, person
            ) AS orden
        FROM DetalleBase
        WHERE LTRIM(RTRIM(cuenta_empleado)) <> ''
    )
    SELECT
        orden,
        LEFT(
            LEFT(CAST(orden AS VARCHAR(10)) + REPLICATE(' ', 7), 7) +
            tipo_doc_txt +
            LEFT(documentnumber + REPLICATE(' ', 11), 11) +
            LEFT(lastname1 + REPLICATE(' ', 20), 20) +
            LEFT(lastname2 + REPLICATE(' ', 20), 20) +
            LEFT(nombres + REPLICATE(' ', 44), 44) +
            REPLICATE(' ', 60) +
            REPLICATE(' ', 10) +
            'H' +
            codbank +
            cuenta_empleado +
            @tipo_moneda +
            RIGHT(
                REPLICATE('0', 14) +
                CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
                14
            ) +
            '5',
            213
        ) AS linea_txt
    FROM Numerado
    ORDER BY orden;
END
GO
