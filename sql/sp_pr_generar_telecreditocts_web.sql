SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    Genera las líneas del archivo Telecrédito CTS del BCP.
    Requiere la tabla temporal #TelecreditoPersonas (person) con los trabajadores
    seleccionados; solo se incluyen los elegibles de sp_pr_listatelecreditocts_web.

    Cabecera (113): 1 | cantidad(6) | fecha abono aaaammdd | subtipo(1) | tipo cta empresa C/M |
                    moneda(4) | cuenta empresa(20) | monto total 99999999999999.99 | referencia(40) |
                    checksum(15)
    Detalle  (195): 2 | tipo cta A/C | cuenta CTS(20) | tipo doc(1) | documento(12) | 3 espacios |
                    nombre(75) | ref. beneficiario(40) | ref. empresa(20) | moneda(4) |
                    importe 99999999999999.99 | 'S'

    Subtipo: PR_ProcessType.subtype del proceso CTS; si no está configurado, espacio.
    Cuenta empresa: TE_BankAccount del banco PR_Mapping.CreditoBank en la moneda del depósito.
    @par_referencia vacío: 'DEPOSITO CTS NOVIEMBRE aaaa - ABRIL aaaa' (mayo) o
    'DEPOSITO CTS MAYO aaaa - OCTUBRE aaaa' (noviembre).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_telecreditocts_web]
    @par_company     VARCHAR(10),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_currency    VARCHAR(2) = 'LO',
    @par_paydate     DATETIME = NULL,
    @par_referencia  VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    SET @par_currency = UPPER(@par_currency);
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    SET @par_referencia = LTRIM(RTRIM(ISNULL(@par_referencia, '')));

    IF OBJECT_ID('tempdb..#TelecreditoPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #TelecreditoPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @moneda_txt      VARCHAR(4);
    DECLARE @subtipo         CHAR(1);
    DECLARE @cuenta_origen   VARCHAR(20);
    DECLARE @tipo_cta_origen CHAR(1);
    DECLARE @ref_planilla    VARCHAR(40);
    DECLARE @mes_ref         VARCHAR(10);
    DECLARE @anio            INT;
    DECLARE @mes             VARCHAR(2);
    DECLARE @total_reg       INT;
    DECLARE @total_cent      BIGINT;
    DECLARE @checksum        BIGINT;
    DECLARE @parte_chk       VARCHAR(30);

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN '1001' ELSE '0001' END;
    SET @anio = CAST(LEFT(@par_period, 4) AS INT);
    SET @mes = SUBSTRING(@par_period, 5, 2);

    SELECT TOP 1
        @cuenta_origen = LEFT(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), '-', ''), ' ', ''), 20),
        @tipo_cta_origen = LEFT(ISNULL(NULLIF(tba.abrev, ''), ISNULL(tmp.abrev, 'C')), 1)
    FROM PR_Mapping m
        INNER JOIN TE_BankAccount ba
            ON ba.Company = m.Company
           AND ba.Bank = m.CreditoBank
           AND ba.AccountCurrency = @par_currency
        LEFT JOIN TE_AccountType tba
            ON tba.AccountType = ba.AccountType
        LEFT JOIN TE_AccountType tmp
            ON tmp.AccountType = m.SalaryAccountType
    WHERE m.Company = @par_company
    ORDER BY ba.BankAccount;

    IF ISNULL(@cuenta_origen, '') = ''
    BEGIN
        RAISERROR('No hay cuenta BCP de la empresa (TE_BankAccount del banco PR_Mapping.CreditoBank) en moneda %s.', 16, 1, @par_currency);
        RETURN;
    END
    IF @tipo_cta_origen NOT IN ('C', 'M') SET @tipo_cta_origen = 'C';

    SELECT TOP 1 @subtipo = LEFT(LTRIM(RTRIM(ISNULL(CAST(pt.subtype AS VARCHAR(10)), ''))), 1)
    FROM PR_ProcessType pt
    WHERE pt.Company = @par_company
      AND pt.ShortName = 'CTS';
    IF ISNULL(@subtipo, '') = '' SET @subtipo = ' ';

    SET @mes_ref = CASE @mes WHEN '05' THEN 'MAY' WHEN '11' THEN 'NOV' ELSE @mes END;
    IF @par_referencia <> ''
        SET @ref_planilla = LEFT(@par_referencia, 40);
    ELSE
        SET @ref_planilla = CASE @mes
            WHEN '05' THEN 'DEPOSITO CTS NOVIEMBRE ' + CAST(@anio - 1 AS VARCHAR(4)) + ' - ABRIL ' + CAST(@anio AS VARCHAR(4))
            WHEN '11' THEN 'DEPOSITO CTS MAYO ' + CAST(@anio AS VARCHAR(4)) + ' - OCTUBRE ' + CAST(@anio AS VARCHAR(4))
            ELSE 'DEPOSITO CTS ' + @par_period
        END;

    CREATE TABLE #Lista (
        person      VARCHAR(30),
        dni         VARCHAR(30),
        tipodoc     VARCHAR(10),
        tipodoc_bcp CHAR(1),
        nombre      VARCHAR(300),
        banco       VARCHAR(200),
        cuenta      VARCHAR(60),
        tipocuenta  CHAR(1),
        moneda_cts  VARCHAR(2),
        importe     DECIMAL(18, 2),
        elegible    CHAR(1),
        motivo      VARCHAR(200)
    );

    INSERT INTO #Lista
    EXEC dbo.sp_pr_listatelecreditocts_web
        @par_company = @par_company,
        @par_payrolltype = @par_payrolltype,
        @par_period = @par_period,
        @par_currency = @par_currency,
        @cesados = 'T',
        @repunit = '0';

    SELECT
        l.person,
        LEFT(l.cuenta, 20) AS cuenta,
        l.tipocuenta,
        l.tipodoc_bcp,
        LEFT(l.dni, 12) AS dni,
        LEFT(l.nombre, 75) AS nombre,
        LEFT('CTS ' + @mes_ref + CAST(@anio AS VARCHAR(4)) + ' ' + l.dni + ' ' + l.nombre, 40) AS refbeneficiario,
        LEFT('CTS ' + l.person, 20) AS refempresa,
        CAST(ROUND(l.importe * 100, 0) AS BIGINT) AS cent
    INTO #Detalle
    FROM #Lista l
        INNER JOIN (
            SELECT DISTINCT LTRIM(RTRIM(person)) AS person
            FROM #TelecreditoPersonas
            WHERE LTRIM(RTRIM(ISNULL(person, ''))) <> ''
        ) ps ON ps.person = l.person
    WHERE l.elegible = 'S';

    SELECT @total_reg = COUNT(*), @total_cent = ISNULL(SUM(cent), 0) FROM #Detalle;

    /* Checksum BCP: cuenta de cargo + cuentas de abono, sin los 3 primeros dígitos. */
    SET @checksum = 0;
    IF LEN(@cuenta_origen) > 3
    BEGIN
        SET @parte_chk = SUBSTRING(@cuenta_origen, 4, LEN(@cuenta_origen) - 3);
        IF @parte_chk NOT LIKE '%[^0-9]%'
            SET @checksum = @checksum + CAST(@parte_chk AS BIGINT);
    END;

    SELECT @checksum = @checksum + ISNULL(SUM(
        CASE
            WHEN LEN(cuenta) > 3 AND SUBSTRING(cuenta, 4, LEN(cuenta) - 3) NOT LIKE '%[^0-9]%'
                THEN CAST(SUBSTRING(cuenta, 4, LEN(cuenta) - 3) AS BIGINT)
            ELSE CAST(0 AS BIGINT)
        END
    ), 0)
    FROM #Detalle;

    SELECT orden, linea_txt
    FROM (
        SELECT
            0 AS orden,
            '1' +
            RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
            CONVERT(VARCHAR(8), @par_paydate, 112) +
            @subtipo +
            @tipo_cta_origen +
            @moneda_txt +
            LEFT(@cuenta_origen + REPLICATE(' ', 20), 20) +
            RIGHT(REPLICATE('0', 14) + CAST(@total_cent / 100 AS VARCHAR(20)), 14) + '.' +
            RIGHT('0' + CAST(@total_cent % 100 AS VARCHAR(2)), 2) +
            LEFT(@ref_planilla + REPLICATE(' ', 40), 40) +
            RIGHT(REPLICATE('0', 15) + CAST(@checksum AS VARCHAR(20)), 15) AS linea_txt
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY nombre, person) AS orden,
            '2' +
            tipocuenta +
            LEFT(cuenta + REPLICATE(' ', 20), 20) +
            tipodoc_bcp +
            LEFT(dni + REPLICATE(' ', 12), 12) +
            '   ' +
            LEFT(nombre + REPLICATE(' ', 75), 75) +
            LEFT(refbeneficiario + REPLICATE(' ', 40), 40) +
            LEFT(refempresa + REPLICATE(' ', 20), 20) +
            @moneda_txt +
            RIGHT(REPLICATE('0', 14) + CAST(cent / 100 AS VARCHAR(20)), 14) + '.' +
            RIGHT('0' + CAST(cent % 100 AS VARCHAR(2)), 2) +
            'S'
        FROM #Detalle
    ) AS lineas
    ORDER BY orden;
END
GO
