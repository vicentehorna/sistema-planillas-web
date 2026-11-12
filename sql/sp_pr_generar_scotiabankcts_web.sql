/*
    Archivo Scotiabank depósito CTS — plantilla SBP CTS NUEVO TBK
    (validado vs AUXILIARES/SCOTIA/CTS NOV.2025-ABR-2026_SCOTIABANK_ADM).

    Sin cabecera. Solo líneas de detalle de 139 caracteres:
       1  tipo documento Scotiabank (DNI=1, CE=3, Pasaporte=4)
      11  documento (DNI/CE, izquierda, relleno espacios)
       1  espacio
      60  nombre
      20  cuenta CTS del trabajador (izquierda; soles con prefijo 1)
      11  espacios
      13  importe (centavos, 13 dígitos con ceros a la izquierda)
      20  glosa/referencia (ej. PAGO DE CTS NOV 2026)
       2  tipo/forma de pago CTS = '05'

    Importe: PR_Mapping.CTSConcept del proceso ShortName CTS.
    Cuenta por línea: PR_Employee.CTSAccount (no la cuenta empresa).
    Glosa: @par_referencia o 'PAGO DE CTS {MES} {AAAA}' del periodo.
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

    DECLARE @scotia_bank VARCHAR(20);
    DECLARE @ref20       VARCHAR(20);
    DECLARE @mes_num     INT;
    DECLARE @anio        VARCHAR(4);
    DECLARE @mes_nom     VARCHAR(10);

    /* Glosa 20 + '05', igual CTS NOV.2025-ABR-2026_SCOTIABANK_ADM. */
    IF @par_referencia <> ''
        SET @ref20 = LEFT(@par_referencia + REPLICATE(' ', 20), 20);
    ELSE
    BEGIN
        SET @mes_num = TRY_CAST(SUBSTRING(@par_period, 5, 2) AS INT);
        SET @anio = LEFT(@par_period, 4);
        SET @mes_nom = CASE @mes_num
            WHEN 1 THEN 'ENE' WHEN 2 THEN 'FEB' WHEN 3 THEN 'MAR'
            WHEN 4 THEN 'ABR' WHEN 5 THEN 'MAYO' WHEN 6 THEN 'JUN'
            WHEN 7 THEN 'JUL' WHEN 8 THEN 'AGO' WHEN 9 THEN 'SET'
            WHEN 10 THEN 'OCT' WHEN 11 THEN 'NOV' WHEN 12 THEN 'DIC'
            ELSE ''
        END;
        IF @mes_nom = '' OR @anio = '' OR LEN(@anio) < 4
            SET @ref20 = LEFT('PAGO DE CTS' + REPLICATE(' ', 20), 20);
        ELSE
            SET @ref20 = LEFT('PAGO DE CTS ' + @mes_nom + ' ' + @anio + REPLICATE(' ', 20), 20);
    END

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
            REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', '') AS cuenta_raw,
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
          AND REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', '') <> ''
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
        LEFT(
            CASE
                WHEN @par_currency = 'LO'
                     AND LEN(cuenta_raw) IN (9, 10)
                     AND LEFT(cuenta_raw, 1) <> '1'
                    THEN '1' + cuenta_raw
                ELSE cuenta_raw
            END + REPLICATE(' ', 20),
            20
        ) AS cuenta_fmt,
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
            @ref20 +
            '05'
        ) AS linea_txt
    FROM #Detalle
    ORDER BY orden;
END
GO
