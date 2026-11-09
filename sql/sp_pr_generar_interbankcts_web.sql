/*
    Archivo Interbank de depósito de CTS (layout fijo según AUXILIARES/INTERBANK).

    Cabecera (96): 1 + servicio CTS (3) + cuenta cargo 20 + PEN/USD + total 15
                   + cantidad 6 + fecha AAAAMMDD + referencia 40.
    Detalle (130): 2 + P/I + cuenta CTS 20 + tipo doc 1 + documento 12
                   + nombre 40 + importe 15 + referencia individual 40.

    Servicio fijo: CTS.
    Cuenta destino: PR_Employee.CTSAccount.
    P si CTSBank = PR_Mapping.interbankbank; I si es otro banco.
    Importe: PR_Mapping.CTSConcept del proceso ShortName CTS.
    Requiere #InterbankCtsPersonas (person) cargada por la app.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_interbankcts_web]
    @par_company     VARCHAR(10),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_currency    VARCHAR(2) = 'LO',
    @par_paydate     DATETIME = NULL,
    @todos_bancos    CHAR(1) = 'N',
    @par_referencia  VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    SET @par_currency = UPPER(@par_currency);
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';
    SET @par_referencia = LTRIM(RTRIM(ISNULL(@par_referencia, '')));

    IF OBJECT_ID('tempdb..#InterbankCtsPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #InterbankCtsPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @cuenta_origen VARCHAR(20);
    DECLARE @interbankbank VARCHAR(20);
    DECLARE @moneda_txt    CHAR(3);
    DECLARE @fecha_txt     CHAR(8);
    DECLARE @ref_txt       VARCHAR(40);
    DECLARE @total_reg     INT;
    DECLARE @total_importe DECIMAL(18, 2);
    DECLARE @importe15     VARCHAR(15);
    DECLARE @linea_cabecera VARCHAR(96);

    SELECT @interbankbank = LTRIM(RTRIM(ISNULL(m.interbankbank, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @interbankbank IS NULL OR @interbankbank = ''
    BEGIN
        RAISERROR('Configure InterbankBank en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SELECT @cuenta_origen = LEFT(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), '-', ''), ' ', ''), 20)
    FROM TE_BankAccount ba
    WHERE ba.Company = @par_company
      AND ba.Bank = @interbankbank
      AND ba.accountcurrency = @par_currency;

    IF @cuenta_origen IS NULL OR LTRIM(RTRIM(@cuenta_origen)) = ''
    BEGIN
        RAISERROR('No se encontró cuenta origen Interbank en TE_BankAccount para la compañía/moneda.', 16, 1);
        RETURN;
    END

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN 'USD' ELSE 'PEN' END;
    SET @fecha_txt = CONVERT(CHAR(8), @par_paydate, 112);
    SET @ref_txt = LEFT(@par_referencia + REPLICATE(' ', 40), 40);

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #InterbankCtsPersonas tp
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
            INNER JOIN PR_Mapping m
                ON m.Company = epc.Company
               AND m.CTSConcept = epc.Concept
            INNER JOIN PR_ProcessType pt
                ON pt.Company = epc.Company
               AND pt.ProcessType = epc.ProcessType
               AND pt.ShortName = 'CTS'
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.prperiod = @par_period
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
            /* 1=DNI, 3=CE; resto espacio */
            CASE
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4') THEN '3'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN '4'
                ELSE ' '
            END AS tipo_doc,
            LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ''))) AS documentnumber,
            UPPER(LTRIM(RTRIM(
                ISNULL(sp.lastname1, '') + ' ' +
                ISNULL(sp.lastname2, '') + ' ' +
                ISNULL(sp.name1, '') + ' ' +
                ISNULL(sp.name2, '')
            ))) AS nombre,
            CASE WHEN e.CTSBank = m.interbankbank THEN 'P' ELSE 'I' END AS tipo_abono,
            LEFT(
                REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', '')
                + REPLICATE(' ', 20),
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
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND ISNULL(m.interbankbank, '') <> ''
          AND ISNULL(NULLIF(LTRIM(RTRIM(e.CTSCurrency)), ''), 'LO') = @par_currency
          AND REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', '') <> ''
          AND (
                (@todos_bancos = 'N' AND e.CTSBank = m.interbankbank)
             OR (@todos_bancos = 'Y' AND ISNULL(e.CTSBank, '') <> '')
          )
    )
    SELECT
        person,
        tipo_doc,
        LEFT(documentnumber + REPLICATE(' ', 12), 12) AS documento_fmt,
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
        '1' +
        'CTS' +
        LEFT(@cuenta_origen + REPLICATE(' ', 20), 20) +
        @moneda_txt +
        @importe15 +
        RIGHT(REPLICATE('0', 6) + CAST(ISNULL(@total_reg, 0) AS VARCHAR(10)), 6) +
        @fecha_txt +
        @ref_txt;

    SELECT orden, linea_txt
    FROM (
        SELECT 0 AS orden, @linea_cabecera AS linea_txt
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY nombre_fmt, person) AS orden,
            (
                '2' +
                tipo_abono +
                cuenta_empleado +
                tipo_doc +
                documento_fmt +
                nombre_fmt +
                importe15 +
                @ref_txt
            ) AS linea_txt
        FROM #Detalle
    ) AS lineas
    ORDER BY orden;
END
GO
