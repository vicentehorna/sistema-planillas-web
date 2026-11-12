SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    Genera las líneas del archivo Telecrédito CTS del BCP.
    Requiere la tabla temporal #TelecreditoPersonas (person) con los trabajadores
    seleccionados; solo se incluyen los elegibles de sp_pr_listatelecreditocts_web.

    Formato estándar (resto de clientes) — cabecera 112 / detalle 195:
      Cabecera: 1 | cantidad(6) | fecha | [subtipo] | tipo cta C/M | moneda(4) | cuenta(20) |
                monto | referencia(40) | checksum(15)
      Detalle:  2 | tipo cta A/C | cuenta(20) | tipodoc | doc(12) | 3 esp | nombre(75) |
                ref benef(40) | ref emp(20) | moneda | importe | 'S'

    Formato hm_maritima (Estructura BCP planilla CTS NTLC) — cabecera 125 / detalle 214:
      Cabecera: 1 | cantidad(6) | fecha | tipo cta C/M | moneda(4) | cuenta(20) | '6' | RUC(12) |
                monto | referencia(40) | checksum(15)
      Detalle:  2 | cuenta(20) | tipodoc | doc(12) | 3 esp | nombre(75) |
                ref benef(40) | ref emp(20) | moneda | importe | '0001' | BASICO_CTS*4
      Ref benef = 'Referencia Beneficiario ' + dni; ref emp = 'Ref Emp ' + dni.
      Referencia cabecera: @par_referencia o 40 espacios.

    Formato hm_aci / hm_ultra / hm_alamo / hm_lumat (wf_calculate / archivo mayo validado por BCP) — cabecera 125 / detalle 214:
      Cabecera: 1 | cantidad(6) | fecha | 'C' | moneda(4) | cuenta(20) | '6' | RUC(12) |
                monto | espacios(40) | checksum(15)
      Detalle:  2 | cuenta(20) | tipodoc | doc(12) | 3 esp | nombre(75) |
                espacios(40) | espacios(20) | moneda | importe | '0001' | BASICO_CTS*4
      Checksum empresa: mid(cuenta,4,11) si SalaryAccountType=A; mid(cuenta,4,10) si no.
      Importe: AmountLo/Ex + interés de PR_EmployeeCTS si existe; si no, concepto CTS.
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
    DECLARE @subtipo         VARCHAR(1);  /* VARCHAR: '' no se convierte en espacio (CHAR sí) */
    DECLARE @cuenta_origen   VARCHAR(20);
    DECLARE @tipo_cta_origen CHAR(1);
    DECLARE @abrev_salary    CHAR(1);
    DECLARE @ref_planilla    VARCHAR(40);
    DECLARE @mes_ref         VARCHAR(10);
    DECLARE @anio            INT;
    DECLARE @mes             VARCHAR(2);
    DECLARE @total_reg       INT;
    DECLARE @total_cent      BIGINT;
    DECLARE @checksum        BIGINT;
    DECLARE @parte_chk       VARCHAR(30);
    DECLARE @es_formato_aci  BIT;  /* hm_aci + hm_ultra + hm_alamo + hm_lumat: cabecera 125 / detalle 214 */
    DECLARE @es_hm_maritima  BIT;
    DECLARE @ruc_empresa     VARCHAR(12);
    DECLARE @chk_len_empresa INT;

    SET @es_formato_aci = CASE
        WHEN LOWER(DB_NAME()) IN ('hm_aci', 'hm_ultra', 'hm_alamo', 'hm_lumat') THEN 1
        ELSE 0
    END;
    SET @es_hm_maritima = CASE WHEN LOWER(DB_NAME()) = 'hm_maritima' THEN 1 ELSE 0 END;
    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN '1001' ELSE '0001' END;
    SET @anio = CAST(LEFT(@par_period, 4) AS INT);
    SET @mes = SUBSTRING(@par_period, 5, 2);

    SELECT TOP 1
        @cuenta_origen = LEFT(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), '-', ''), ' ', ''), 20),
        @tipo_cta_origen = LEFT(ISNULL(NULLIF(tba.abrev, ''), ISNULL(tmp.abrev, 'C')), 1),
        @abrev_salary = LEFT(ISNULL(NULLIF(tmp.abrev, ''), 'C'), 1)
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
    IF ISNULL(@abrev_salary, '') = '' SET @abrev_salary = 'C';

    SELECT TOP 1 @subtipo = LEFT(LTRIM(RTRIM(ISNULL(CAST(pt.subtype AS VARCHAR(10)), ''))), 1)
    FROM PR_ProcessType pt
    WHERE pt.Company = @par_company
      AND pt.ShortName = 'CTS';
    /* Vacío = no emitir (cabecera 112). Antes se ponía espacio y BCP rechazaba por largo. */
    IF ISNULL(@subtipo, '') = '' SET @subtipo = '';
    /* Marítima (mayo BCP): sin subtipo en cabecera. */
    IF @es_hm_maritima = 1 SET @subtipo = '';

    SELECT TOP 1 @ruc_empresa = LEFT(LTRIM(RTRIM(ISNULL(c.Ruc, ''))) + REPLICATE(' ', 12), 12)
    FROM SY_Company c
    WHERE c.Company = @par_company;
    IF @ruc_empresa IS NULL SET @ruc_empresa = REPLICATE(' ', 12);

    SET @mes_ref = CASE @mes WHEN '05' THEN 'MAY' WHEN '11' THEN 'NOV' ELSE @mes END;
    IF @es_hm_maritima = 1
        /* NTLC: referencia cabecera opcional; si no viene, 40 espacios. */
        SET @ref_planilla = CASE
            WHEN @par_referencia <> '' THEN LEFT(@par_referencia + REPLICATE(' ', 40), 40)
            ELSE REPLICATE(' ', 40)
        END;
    ELSE IF @par_referencia <> ''
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
        CASE
            WHEN @es_hm_maritima = 1 THEN
                LEFT('Referencia Beneficiario ' + LTRIM(RTRIM(ISNULL(l.dni, ''))) + REPLICATE(' ', 40), 40)
            ELSE
                LEFT('CTS ' + @mes_ref + CAST(@anio AS VARCHAR(4)) + ' ' + l.dni + ' ' + l.nombre, 40)
        END AS refbeneficiario,
        CASE
            WHEN @es_hm_maritima = 1 THEN
                LEFT('Ref Emp ' + LTRIM(RTRIM(ISNULL(l.dni, ''))) + REPLICATE(' ', 20), 20)
            ELSE
                LEFT('CTS ' + l.person, 20)
        END AS refempresa,
        CAST(ROUND(
            COALESCE(
                CASE
                    WHEN @es_formato_aci = 1 AND ects.Person IS NOT NULL THEN
                        CASE
                            WHEN @par_currency = 'EX'
                                THEN ISNULL(ects.AmountEx, 0) + ISNULL(ects.AmountInterestEx, 0)
                            ELSE ISNULL(ects.AmountLo, 0) + ISNULL(ects.AmountInterestLo, 0)
                        END
                    ELSE l.importe
                END,
                l.importe,
                0
            ) * 100, 0
        ) AS BIGINT) AS cent,
        CAST(ROUND(
            ISNULL(bas.basico_cts, 0) * 4 * 100, 0
        ) AS BIGINT) AS cent_cts_anios
    INTO #Detalle
    FROM #Lista l
        INNER JOIN (
            SELECT DISTINCT LTRIM(RTRIM(person)) AS person
            FROM #TelecreditoPersonas
            WHERE LTRIM(RTRIM(ISNULL(person, ''))) <> ''
        ) ps ON ps.person = l.person
        LEFT JOIN PR_EmployeeCTS ects
            ON ects.Company = @par_company
           AND ects.PayRollType = @par_payrolltype
           AND ects.PRPeriod = @par_period
           AND ects.Person = l.person
        LEFT JOIN (
            SELECT
                epc.Person,
                MAX(CASE WHEN @par_currency = 'EX' THEN ISNULL(epc.ConceptValueEx, 0) ELSE ISNULL(epc.ConceptValueLo, 0) END) AS basico_cts
            FROM PR_EmployeePayRollConcept epc
                INNER JOIN PR_Concept c
                    ON c.Company = epc.Company
                   AND c.Concept = epc.Concept
                   AND c.FormulaCode = 'BASICO_CTS'
                INNER JOIN PR_ProcessType pt
                    ON pt.Company = epc.Company
                   AND pt.ProcessType = epc.ProcessType
                   AND pt.ShortName = 'CTS'
            WHERE epc.Company = @par_company
              AND epc.PayRollType = @par_payrolltype
              AND epc.PRPeriod = @par_period
            GROUP BY epc.Person
        ) bas ON bas.Person = l.person
    WHERE l.elegible = 'S';

    SELECT @total_reg = COUNT(*), @total_cent = ISNULL(SUM(cent), 0) FROM #Detalle;

    /* Checksum BCP: cuenta de cargo + cuentas de abono. */
    SET @checksum = 0;
    IF @es_formato_aci = 1
    BEGIN
        /* wf_calculate: A → mid(4,11); otro → mid(4,10). */
        SET @chk_len_empresa = CASE WHEN @abrev_salary = 'A' THEN 11 ELSE 10 END;
        IF LEN(@cuenta_origen) >= 4
        BEGIN
            SET @parte_chk = SUBSTRING(@cuenta_origen, 4, @chk_len_empresa);
            IF @parte_chk NOT LIKE '%[^0-9]%' AND @parte_chk <> ''
                SET @checksum = @checksum + CAST(@parte_chk AS BIGINT);
        END
    END
    ELSE IF LEN(@cuenta_origen) > 3
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

    IF @es_formato_aci = 1
    BEGIN
        /* Estructura mayo / wf_calculate (hm_aci, hm_ultra, hm_alamo, hm_lumat): cabecera 125, detalle 214. */
        SELECT orden, linea_txt
        FROM (
            SELECT
                0 AS orden,
                '1' +
                RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
                CONVERT(VARCHAR(8), @par_paydate, 112) +
                'C' +
                @moneda_txt +
                LEFT(@cuenta_origen + REPLICATE(' ', 20), 20) +
                '6' +
                @ruc_empresa +
                RIGHT(REPLICATE('0', 14) + CAST(@total_cent / 100 AS VARCHAR(20)), 14) + '.' +
                RIGHT('0' + CAST(@total_cent % 100 AS VARCHAR(2)), 2) +
                REPLICATE(' ', 40) +
                RIGHT(REPLICATE('0', 15) + CAST(@checksum AS VARCHAR(20)), 15) AS linea_txt
            UNION ALL
            SELECT
                ROW_NUMBER() OVER (ORDER BY nombre, person) AS orden,
                '2' +
                LEFT(cuenta + REPLICATE(' ', 20), 20) +
                tipodoc_bcp +
                LEFT(dni + REPLICATE(' ', 12), 12) +
                '   ' +
                LEFT(nombre + REPLICATE(' ', 75), 75) +
                REPLICATE(' ', 40) +
                REPLICATE(' ', 20) +
                @moneda_txt +
                RIGHT(REPLICATE('0', 14) + CAST(cent / 100 AS VARCHAR(20)), 14) + '.' +
                RIGHT('0' + CAST(cent % 100 AS VARCHAR(2)), 2) +
                '0001' +
                RIGHT(REPLICATE('0', 14) + CAST(cent_cts_anios / 100 AS VARCHAR(20)), 14) + '.' +
                RIGHT('0' + CAST(cent_cts_anios % 100 AS VARCHAR(2)), 2)
            FROM #Detalle
        ) AS lineas
        ORDER BY orden;
    END
    ELSE IF @es_hm_maritima = 1
    BEGIN
        /* Estructura BCP CTS NTLC (solo hm_maritima): cabecera 125, detalle 214. */
        SELECT orden, linea_txt
        FROM (
            SELECT
                0 AS orden,
                '1' +
                RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
                CONVERT(VARCHAR(8), @par_paydate, 112) +
                @tipo_cta_origen +
                @moneda_txt +
                LEFT(@cuenta_origen + REPLICATE(' ', 20), 20) +
                '6' +
                @ruc_empresa +
                RIGHT(REPLICATE('0', 14) + CAST(@total_cent / 100 AS VARCHAR(20)), 14) + '.' +
                RIGHT('0' + CAST(@total_cent % 100 AS VARCHAR(2)), 2) +
                LEFT(@ref_planilla + REPLICATE(' ', 40), 40) +
                RIGHT(REPLICATE('0', 15) + CAST(@checksum AS VARCHAR(20)), 15) AS linea_txt
            UNION ALL
            SELECT
                ROW_NUMBER() OVER (ORDER BY nombre, person) AS orden,
                '2' +
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
                '0001' +
                RIGHT(REPLICATE('0', 14) + CAST(cent_cts_anios / 100 AS VARCHAR(20)), 14) + '.' +
                RIGHT('0' + CAST(cent_cts_anios % 100 AS VARCHAR(2)), 2)
            FROM #Detalle
        ) AS lineas
        ORDER BY orden;
    END
    ELSE
    BEGIN
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
END
GO
