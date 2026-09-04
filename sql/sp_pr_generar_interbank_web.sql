/*
    Genera líneas del archivo Interbank (cabecera tipo 01 + detalle tipo 02).
    Layout según Macro Pagos Masivos Interbank / txt_ibk.txt (haberes, servicio 04):
      Cabecera 104 chars | Detalle 380 chars.
    Requiere #InterbankPersonas (person) cargada por la app web.
    Banco destino: pr_mapping.interbankbank.
    Código empresa en cabecera (pos. 100-104): MC001 (temporal, en duro).
    @par_referencia: texto cabecera TXT (36 chars, pos. 5-40). Si vacío, espacios.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_interbank_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @par_referencia  VARCHAR(36) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    SET @par_referencia = LTRIM(RTRIM(ISNULL(@par_referencia, '')));

    IF OBJECT_ID('tempdb..#InterbankPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #InterbankPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @fecha_envio     VARCHAR(14);
    DECLARE @codigo_empresa  VARCHAR(5);
    DECLARE @ref_cabecera    VARCHAR(36);
    DECLARE @total_reg       INT;
    DECLARE @total_soles     DECIMAL(18, 2);
    DECLARE @total_dolares   DECIMAL(18, 2);
    DECLARE @importe_soles   VARCHAR(17);
    DECLARE @importe_dolares VARCHAR(13);
    DECLARE @linea_cabecera  VARCHAR(104);

    SET @fecha_envio =
        CONVERT(VARCHAR(8), GETDATE(), 112) +
        RIGHT('0' + CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)), 2) +
        RIGHT('0' + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)), 2) +
        RIGHT('0' + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2)), 2);

    SET @codigo_empresa = 'MC001';
    SET @ref_cabecera = LEFT(@par_referencia + REPLICATE(' ', 36), 36);

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #InterbankPersonas tp
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
    ),
    DetalleBase AS (
        SELECT
            e.person,
            LTRIM(RTRIM(ISNULL(e.salaryaccount, ''))) AS cuenta_raw,
            ISNULL(tat.abrev, 'A') AS tipocuenta_abrev,
            CASE
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN '01'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4', '03', '3') THEN '03'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN '04'
                WHEN ISNULL(pdt.PDT, '') IN ('06', '6') THEN '06'
                ELSE '01'
            END AS tipodocumento,
            LTRIM(RTRIM(
                CASE
                    WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                    ELSE sp.DocumentNumber
                END
            )) AS numerodocumento,
            LTRIM(RTRIM(ISNULL(sp.lastname1, ''))) AS apellido1,
            LTRIM(RTRIM(ISNULL(sp.lastname2, ''))) AS apellido2,
            LTRIM(RTRIM(
                LTRIM(RTRIM(ISNULL(sp.name1, ''))) +
                CASE
                    WHEN LTRIM(RTRIM(ISNULL(sp.name2, ''))) <> ''
                        THEN ' ' + LTRIM(RTRIM(sp.name2))
                    ELSE ''
                END
            )) AS nombres,
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
    ),
    DetalleCuenta AS (
        SELECT
            db.*,
            CASE
                WHEN LEFT(db.cuenta_raw, 2) = '09' AND LEN(db.cuenta_raw) > 13
                    THEN SUBSTRING(db.cuenta_raw, 3, LEN(db.cuenta_raw))
                ELSE db.cuenta_raw
            END AS cuenta_limpia,
            CASE WHEN db.tipocuenta_abrev = 'B' THEN '99' ELSE '09' END AS tipo_abono
        FROM DetalleBase db
    )
    SELECT
        person,
        LEFT(
            dc.tipo_abono +
            CASE
                WHEN dc.tipo_abono = '99' THEN REPLICATE(' ', 3)
                ELSE
                    CASE dc.tipocuenta_abrev
                        WHEN 'C' THEN '001'
                        WHEN 'A' THEN '002'
                        ELSE '002'
                    END
            END +
            CASE
                WHEN dc.tipo_abono = '99' THEN REPLICATE(' ', 2)
                WHEN @par_currency = 'EX' THEN '10'
                ELSE '01'
            END +
            CASE
                WHEN dc.tipo_abono = '99' THEN REPLICATE(' ', 3)
                WHEN LEN(dc.cuenta_limpia) >= 3 THEN LEFT(dc.cuenta_limpia, 3)
                ELSE REPLICATE(' ', 3)
            END +
            LEFT(
                CASE
                    WHEN dc.tipo_abono = '99' THEN dc.cuenta_limpia
                    WHEN LEN(dc.cuenta_limpia) >= 4 THEN SUBSTRING(dc.cuenta_limpia, 4, 10)
                    ELSE dc.cuenta_limpia
                END + REPLICATE(' ', 20),
                20
            ),
            30
        ) AS bloque_abono,
        CASE WHEN @par_currency = 'EX' THEN '10' ELSE '01' END AS moneda_abono,
        tipodocumento,
        numerodocumento,
        apellido1,
        apellido2,
        nombres,
        importe,
        RIGHT(
            REPLICATE('0', 15) +
            CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
            15
        ) AS importe15,
        RIGHT(REPLICATE('0', 20) + numerodocumento, 20) AS codigo_beneficiario,
        LEFT(numerodocumento + REPLICATE(' ', 15), 15) AS numdoc_fmt,
        LEFT(
            LTRIM(RTRIM(
                LTRIM(RTRIM(apellido1)) +
                CASE WHEN LTRIM(RTRIM(apellido2)) <> '' THEN ' ' + LTRIM(RTRIM(apellido2)) ELSE '' END +
                CASE WHEN LTRIM(RTRIM(nombres)) <> '' THEN ' ' + LTRIM(RTRIM(nombres)) ELSE '' END
            )) + REPLICATE(' ', 60),
            60
        ) AS nombre_fmt
    INTO #Detalle
    FROM DetalleCuenta dc;

    SELECT @total_reg = COUNT(*) FROM #Detalle;

    IF @par_currency = 'LO'
    BEGIN
        SELECT @total_soles = ISNULL(SUM(importe), 0) FROM #Detalle;
        SET @total_dolares = 0;
    END
    ELSE
    BEGIN
        SELECT @total_dolares = ISNULL(SUM(importe), 0) FROM #Detalle;
        SET @total_soles = 0;
    END

    SET @importe_soles = RIGHT(
        REPLICATE('0', 17) +
        CAST(CAST(ROUND(ISNULL(@total_soles, 0), 2) * 10000 AS BIGINT) AS VARCHAR(20)),
        17
    );
    SET @importe_dolares = RIGHT(
        REPLICATE('0', 13) +
        CAST(CAST(ROUND(ISNULL(@total_dolares, 0), 2) * 10000 AS BIGINT) AS VARCHAR(20)),
        13
    );

    SET @linea_cabecera =
        '01' +
        '04' +
        @ref_cabecera +
        @fecha_envio +
        REPLICATE(' ', 9) +
        RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
        @importe_soles +
        @importe_dolares +
        LEFT(@codigo_empresa + REPLICATE(' ', 5), 5);

    /*
        Detalle tipo 02 (380 chars, spec Interbank Pago Haberes):
        02(2) + cod.beneficiario(20) + doc.pago(21) + fecha(8) + moneda abono(2)
        + monto(15) + filler(1) + abono cuenta(30) + tipo persona(1) + tipo doc(2)
        + num doc(15) + nombre(60) + moneda CTS(2) + monto CTS(15) + filler(6)
        + celular(40) + email(140)
    */
    ;WITH DetalleSeq AS (
        SELECT
            d.*,
            ROW_NUMBER() OVER (ORDER BY d.apellido1, d.apellido2, d.nombres, d.person) AS seq
        FROM #Detalle d
    )
    SELECT orden, linea_txt
    FROM (
        SELECT 0 AS orden, @linea_cabecera AS linea_txt
        UNION ALL
        SELECT
            seq AS orden,
            LEFT(
                '02' +
                codigo_beneficiario +
                ' ' +
                REPLICATE(' ', 20) +
                REPLICATE(' ', 8) +
                moneda_abono +
                importe15 +
                ' ' +
                bloque_abono +
                'P' +
                tipodocumento +
                numdoc_fmt +
                nombre_fmt +
                REPLICATE(' ', 2) +
                '000000000000000' +
                REPLICATE(' ', 6) +
                REPLICATE(' ', 40) +
                REPLICATE(' ', 140),
                380
            ) AS linea_txt
        FROM DetalleSeq
    ) AS lineas
    ORDER BY orden;
END
GO
