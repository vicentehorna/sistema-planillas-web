/*
    Archivo Scotiabank depósito CTS — plantilla SBP CTS NUEVO TBK
    (validado contra AUXILIARES/SCOTIA/ABONOS.txt del sistema anterior, mayo).

    Sin cabecera. Solo líneas de detalle de 139 caracteres:
       1  tipo documento Scotiabank (DNI=1, CE=3, Pasaporte=4)
      11  documento (DNI/CE, izquierda, relleno espacios)
       1  espacio
      60  nombre
      20  cuenta cargo empresa Scotiabank (izquierda)
      11  espacios
      13  importe (centavos, 13 dígitos con ceros a la izquierda)
      20  espacios
       2  tipo/forma de pago CTS = '05'

    Importe: PR_Mapping.CTSConcept del proceso ShortName CTS.
    Cuenta por línea: cuenta origen Scotiabank de la empresa (igual que ABONOS mayo).
    Requiere #ScotiabankCtsPersonas (person) cargada por la app.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_scotiabankcts_web]
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

    IF OBJECT_ID('tempdb..#ScotiabankCtsPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #ScotiabankCtsPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @cuenta_origen VARCHAR(20);
    DECLARE @scotia_bank   VARCHAR(20);

    SELECT TOP 1 @scotia_bank = LTRIM(RTRIM(b.Bank))
    FROM ERP_Bank b
    WHERE b.Company = @par_company
      AND UPPER(ISNULL(b.Name, '')) LIKE '%SCOTIABANK%'
    ORDER BY b.Bank;

    IF @scotia_bank IS NULL OR @scotia_bank = ''
    BEGIN
        RAISERROR('No se encontró banco Scotiabank en ERP_Bank para la compañía.', 16, 1);
        RETURN;
    END

    /* Preferir la cuenta Scotiabank más larga en la moneda (CTS empresa). */
    SELECT TOP 1 @cuenta_origen = LEFT(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), '-', ''), ' ', ''), 20)
    FROM TE_BankAccount ba
    WHERE ba.Company = @par_company
      AND ba.Bank = @scotia_bank
      AND ba.accountcurrency = @par_currency
    ORDER BY LEN(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), '-', ''), ' ', '')) DESC,
             ba.BankAccountNumber;

    IF @cuenta_origen IS NULL OR LTRIM(RTRIM(@cuenta_origen)) = ''
    BEGIN
        RAISERROR('No se encontró cuenta origen Scotiabank en TE_BankAccount para la compañía/moneda.', 16, 1);
        RETURN;
    END

    /* Mayo ABONOS / SBP CTS: soles suele ir con prefijo 1 (376153240 → 1376153240). */
    IF @par_currency = 'LO'
       AND LEN(@cuenta_origen) = 9
       AND LEFT(@cuenta_origen, 1) <> '1'
        SET @cuenta_origen = '1' + @cuenta_origen;

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #ScotiabankCtsPersonas tp
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
            CASE
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4') THEN '3'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN '4'
                ELSE LEFT(LTRIM(RTRIM(ISNULL(NULLIF(pdt.PDT, ''), '1'))) + '1', 1)
            END AS tipo_doc_txt,
            LTRIM(RTRIM(ISNULL(sp.DocumentNumber, e.person))) AS documentnumber,
            UPPER(LTRIM(RTRIM(
                ISNULL(sp.lastname1, '') + ' ' +
                ISNULL(sp.lastname2, '') + ' ' +
                ISNULL(sp.name1, '') + ' ' +
                ISNULL(sp.name2, '')
            ))) AS nombre,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
            LEFT JOIN ERP_Bank eb
                ON eb.Bank = e.CTSBank
               AND eb.Company = e.Company
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND ISNULL(NULLIF(LTRIM(RTRIM(e.CTSCurrency)), ''), 'LO') = @par_currency
          AND (
                (
                    @todos_bancos = 'N'
                    AND (
                        UPPER(ISNULL(eb.Name, '')) LIKE '%SCOTIABANK%'
                     OR UPPER(ISNULL(e.CTSBank, '')) LIKE '%SCOTIABANK%'
                     OR e.CTSBank = @scotia_bank
                    )
                )
             OR (
                    @todos_bancos = 'Y'
                    AND ISNULL(e.CTSBank, '') <> ''
                )
          )
    )
    SELECT
        person,
        tipo_doc_txt,
        LEFT(LTRIM(RTRIM(ISNULL(documentnumber, ''))) + REPLICATE(' ', 11), 11) AS documento_fmt,
        LEFT(LTRIM(RTRIM(ISNULL(nombre, ''))) + REPLICATE(' ', 60), 60) AS nombre_fmt,
        LEFT(@cuenta_origen + REPLICATE(' ', 20), 20) AS cuenta_fmt,
        importe,
        RIGHT(
            REPLICATE('0', 13) +
            CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
            13
        ) AS importe13
    INTO #Detalle
    FROM DetalleBase;

    /* SBP CTS NUEVO TBK: solo detalle 139, sin cabecera. */
    SELECT
        ROW_NUMBER() OVER (ORDER BY nombre_fmt, person) AS orden,
        (
            tipo_doc_txt +
            documento_fmt +
            ' ' +
            nombre_fmt +
            cuenta_fmt +
            REPLICATE(' ', 11) +
            importe13 +
            REPLICATE(' ', 20) +
            '05'
        ) AS linea_txt
    FROM #Detalle
    ORDER BY orden;
END
GO
