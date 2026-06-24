/*
    Genera archivo Continental / BBVA (cabecera 151 + detalle 233 chars).
    Requiere #ContinentalPersonas (person) cargada por la app web.
    Banco destino: pr_mapping.continentalbank.
    Cuenta origen: TE_BankAccount vía continentalbank y moneda.
    @todos_bancos: N = solo cuenta propia Continental; Y = cuenta propia Continental + interbancarios.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_continental_web]
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

    IF OBJECT_ID('tempdb..#ContinentalPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #ContinentalPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @tipo_operacion   CHAR(3);
    DECLARE @cuenta_origen    VARCHAR(20);
    DECLARE @moneda_txt       CHAR(3);
    DECLARE @collectionform   VARCHAR(20);
    DECLARE @continentalbank  VARCHAR(20);
    DECLARE @ref_cabecera     VARCHAR(25);
    DECLARE @ref_detalle      VARCHAR(40);
    DECLARE @empresa_aci      CHAR(1);
    DECLARE @total_reg        INT;
    DECLARE @total_importe    DECIMAL(18, 2);
    DECLARE @importe15        VARCHAR(15);
    DECLARE @linea_cabecera   VARCHAR(151);

    SELECT @collectionform = LTRIM(RTRIM(ISNULL(m.collectionform, ''))),
           @continentalbank = LTRIM(RTRIM(ISNULL(m.continentalbank, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @collectionform = ''
    BEGIN
        RAISERROR('Configure la forma de pago (CollectionForm) en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    IF @continentalbank = ''
    BEGIN
        RAISERROR('Configure ContinentalBank en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SELECT @cuenta_origen = LEFT(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), 20)
    FROM TE_BankAccount ba
    WHERE ba.Company = @par_company
      AND ba.Bank = @continentalbank
      AND ba.accountcurrency = @par_currency;

    IF @cuenta_origen IS NULL OR LTRIM(RTRIM(@cuenta_origen)) = ''
    BEGIN
        RAISERROR('No se encontró cuenta origen Continental en TE_BankAccount para la compañía/moneda.', 16, 1);
        RETURN;
    END

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN 'USD' ELSE 'PEN' END;

    IF EXISTS (
        SELECT 1
        FROM PR_PayRollType pt
        WHERE pt.Company = @par_company
          AND pt.PayRollType = @par_payrolltype
          AND (
                UPPER(ISNULL(pt.ShortName, '')) LIKE '%4TA%'
             OR UPPER(ISNULL(pt.ShortName, '')) LIKE '%HONORARIOS%'
          )
    )
        SET @tipo_operacion = '800';
    ELSE
        SET @tipo_operacion = '700';

    SELECT @ref_cabecera = LEFT(
        LTRIM(RTRIM(ISNULL(pt.Description, ISNULL(pt.ShortName, @par_processtype)))),
        25
    )
    FROM PR_ProcessType pt
    WHERE pt.Company = @par_company
      AND pt.ProcessType = @par_processtype;

    IF @ref_cabecera IS NULL SET @ref_cabecera = '';
    SET @ref_cabecera = LEFT(@ref_cabecera + REPLICATE(' ', 25), 25);

    SELECT @ref_detalle = LEFT(
        LTRIM(RTRIM(ISNULL(pc.Description, @par_concept))),
        40
    )
    FROM PR_Concept pc
    WHERE pc.Company = @par_company
      AND pc.Concept = @par_concept;

    IF @ref_detalle IS NULL SET @ref_detalle = '';
    SET @ref_detalle = LEFT(@ref_detalle + REPLICATE(' ', 40), 40);

    IF EXISTS (
        SELECT 1 FROM sy_company sc
        WHERE sc.company = @par_company
          AND LTRIM(RTRIM(ISNULL(sc.email_server, ''))) = 'ACI'
    )
        SET @empresa_aci = 'Y';
    ELSE
        SET @empresa_aci = 'N';

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #ContinentalPersonas tp
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
                WHEN ISNULL(sp.Ruc, '') <> '' AND ISNULL(sp.flagrucpersontype, '') = '20' THEN 'R'
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN 'L'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4') THEN 'E'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN 'P'
                ELSE 'L'
            END AS doi_tipo,
            LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(ISNULL(sp.Ruc, ''))) AS ruc,
            LTRIM(RTRIM(ISNULL(sp.lastdocumentnumber, ''))) AS lastdocumentnumber,
            UPPER(LTRIM(RTRIM(
                ISNULL(sp.lastname1, '') + ' ' +
                ISNULL(sp.lastname2, '') + ' ' +
                ISNULL(sp.name1, '') + ' ' +
                ISNULL(sp.name2, '')
            ))) AS nombre,
            CASE WHEN e.salarybank = m.continentalbank THEN 'P' ELSE 'I' END AS tipo_abono,
            LEFT(
                LTRIM(RTRIM(
                    CASE
                        WHEN ISNULL(tat.abrev, '') = 'B' AND @empresa_aci = 'Y'
                            THEN ISNULL(e.socialassistancenumber, '')
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
            LEFT JOIN te_accounttype tat
                ON tat.accounttype = e.salaryaccounttype
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND e.salarycurrency = @par_currency
          AND ISNULL(m.continentalbank, '') <> ''
          AND e.collectionform = @collectionform
          AND (
                (@todos_bancos = 'N' AND e.salarybank = m.continentalbank)
             OR (
                    @todos_bancos = 'Y'
                    AND (
                        (
                            e.salarybank = m.continentalbank
                            AND ISNULL(e.salaryaccount, '') <> ''
                        )
                     OR (
                            e.salarybank <> m.continentalbank
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
    )
    SELECT
        person,
        doi_tipo,
        CASE
            WHEN doi_tipo = 'R' THEN LEFT(ruc + REPLICATE(' ', 12), 12)
            WHEN doi_tipo = 'E' THEN LEFT(lastdocumentnumber + REPLICATE(' ', 12), 12)
            ELSE LEFT(documentnumber + REPLICATE(' ', 12), 12)
        END AS documento_fmt,
        tipo_abono,
        cuenta_empleado,
        LEFT(nombre + REPLICATE(' ', 40), 40) AS nombre_fmt,
        importe,
        RIGHT(
            REPLICATE('0', 15) +
            CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
            15
        ) AS importe15
    INTO #Detalle
    FROM DetalleBase
    WHERE LTRIM(RTRIM(cuenta_empleado)) <> '';

    SELECT @total_reg = COUNT(*), @total_importe = ISNULL(SUM(importe), 0)
    FROM #Detalle;

    SET @importe15 = RIGHT(
        REPLICATE('0', 15) +
        CAST(CAST(ROUND(ISNULL(@total_importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
        15
    );

    SET @linea_cabecera =
        @tipo_operacion +
        LEFT(@cuenta_origen + REPLICATE(' ', 20), 20) +
        @moneda_txt +
        @importe15 +
        'A' +
        REPLICATE(' ', 8) +
        REPLICATE(' ', 1) +
        @ref_cabecera +
        RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
        'S' +
        REPLICATE(' ', 68);

    SELECT orden, linea_txt
    FROM (
        SELECT 0 AS orden, @linea_cabecera AS linea_txt
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY nombre_fmt, person) AS orden,
            LEFT(
                '002' +
                doi_tipo +
                documento_fmt +
                tipo_abono +
                cuenta_empleado +
                nombre_fmt +
                importe15 +
                @ref_detalle +
                REPLICATE(' ', 101),
                233
            ) AS linea_txt
        FROM #Detalle
    ) AS lineas
    ORDER BY orden;
END
GO
