/*
    Genera líneas del archivo Interbank CTS (cabecera tipo 01 + detalle tipo 02).
    Layout Macro Pagos Masivos Interbank (mismo que haberes, servicio 06 CTS):
      Cabecera 104 chars | Detalle 380 chars.
    Validado contra AUXILIARES/SCOTIA/CTS 05 TECNICOS.txt (hm_ultra mayo 2026).

    Requiere #InterbankCtsPersonas (person) cargada por la app web.
    Cuenta destino: PR_Employee.CTSAccount / CTSBank.
    Importe abono: PR_Mapping.CTSConcept del proceso ShortName CTS.
    Monto CTS (pos. detalle): hm_ultra = REM_ACUM_RELACIONADA; resto = BASICO_CTS * 4.
    Código empresa en cabecera (pos. 100-104): MC001 (temporal, en duro).
    Tipo de cuenta Interbank CTS en bloque abono: 007.
    @par_referencia: texto cabecera TXT (36 chars, pos. 5-40). Si vacío, espacios.
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

    DECLARE @fecha_envio     VARCHAR(14);
    DECLARE @codigo_empresa  VARCHAR(5);
    DECLARE @ref_cabecera    VARCHAR(36);
    DECLARE @total_reg       INT;
    DECLARE @total_soles     DECIMAL(18, 2);
    DECLARE @total_dolares   DECIMAL(18, 2);
    DECLARE @importe_soles   VARCHAR(17);
    DECLARE @importe_dolares VARCHAR(13);
    DECLARE @linea_cabecera  VARCHAR(104);
    DECLARE @interbankbank   VARCHAR(20);

    SELECT @interbankbank = LTRIM(RTRIM(ISNULL(m.interbankbank, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @interbankbank IS NULL OR @interbankbank = ''
    BEGIN
        RAISERROR('Configure InterbankBank en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SET @fecha_envio =
        CONVERT(VARCHAR(8), GETDATE(), 112) +
        RIGHT('0' + CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)), 2) +
        RIGHT('0' + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)), 2) +
        RIGHT('0' + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2)), 2);

    SET @codigo_empresa = 'MC001';
    SET @ref_cabecera = LEFT(@par_referencia + REPLICATE(' ', 36), 36);

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
    RemCts AS (
        SELECT
            epc.Person,
            MAX(CASE
                WHEN UPPER(LTRIM(RTRIM(c.FormulaCode))) = 'BASICO_CTS' THEN
                    CASE
                        WHEN @par_currency = 'EX' THEN ISNULL(epc.ConceptValueEx, 0)
                        ELSE ISNULL(epc.ConceptValueLo, 0)
                    END
            END) AS basico_cts,
            MAX(CASE
                WHEN UPPER(LTRIM(RTRIM(c.FormulaCode))) = 'REM_ACUM_RELACIONADA' THEN
                    CASE
                        WHEN @par_currency = 'EX' THEN ISNULL(epc.ConceptValueEx, 0)
                        ELSE ISNULL(epc.ConceptValueLo, 0)
                    END
            END) AS rem_4ult
        FROM PR_EmployeePayRollConcept epc
            INNER JOIN PersonasSel ps ON ps.person = epc.Person
            INNER JOIN PR_Concept c
                ON c.Company = epc.Company
               AND c.Concept = epc.Concept
               AND UPPER(LTRIM(RTRIM(c.FormulaCode))) IN ('BASICO_CTS', 'REM_ACUM_RELACIONADA')
            INNER JOIN PR_ProcessType pt
                ON pt.Company = epc.Company
               AND pt.ProcessType = epc.ProcessType
               AND pt.ShortName = 'CTS'
        WHERE epc.Company = @par_company
          AND epc.PayRollType = @par_payrolltype
          AND epc.PRPeriod = @par_period
        GROUP BY epc.Person
    ),
    DetalleBase AS (
        SELECT
            e.person,
            LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))) AS cuenta_raw,
            CASE WHEN e.CTSBank = m.interbankbank THEN 'P' ELSE 'I' END AS tipo_abono_pi,
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
            UPPER(LTRIM(RTRIM(ISNULL(sp.lastname1, '')))) AS apellido1,
            UPPER(LTRIM(RTRIM(ISNULL(sp.lastname2, '')))) AS apellido2,
            UPPER(LTRIM(RTRIM(
                LTRIM(RTRIM(ISNULL(sp.name1, ''))) +
                CASE
                    WHEN LTRIM(RTRIM(ISNULL(sp.name2, ''))) <> ''
                        THEN ' ' + LTRIM(RTRIM(sp.name2))
                    ELSE ''
                END
            ))) AS nombres,
            p.importe,
            CASE
                WHEN LOWER(DB_NAME()) = 'hm_ultra' THEN ISNULL(bas.rem_4ult, 0)
                ELSE ISNULL(bas.basico_cts, 0) * 4
            END AS monto_4ult
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN RemCts bas ON bas.Person = e.person
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
                WHEN LEFT(REPLACE(REPLACE(db.cuenta_raw, '-', ''), ' ', ''), 2) = '09'
                 AND LEN(REPLACE(REPLACE(db.cuenta_raw, '-', ''), ' ', '')) > 13
                    THEN SUBSTRING(REPLACE(REPLACE(db.cuenta_raw, '-', ''), ' ', ''), 3,
                                   LEN(REPLACE(REPLACE(db.cuenta_raw, '-', ''), ' ', '')))
                ELSE REPLACE(REPLACE(db.cuenta_raw, '-', ''), ' ', '')
            END AS cuenta_limpia,
            CASE WHEN db.tipo_abono_pi = 'P' THEN '09' ELSE '99' END AS tipo_abono
        FROM DetalleBase db
    )
    SELECT
        person,
        LEFT(
            dc.tipo_abono +
            CASE
                WHEN dc.tipo_abono = '99' THEN REPLICATE(' ', 3)
                ELSE '007' /* tipo cuenta CTS Interbank Macro Pagos */
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
        CAST(ROUND(ISNULL(monto_4ult, 0), 2) AS DECIMAL(18, 2)) AS importe_cts,
        RIGHT(
            REPLICATE('0', 15) +
            CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
            15
        ) AS importe15,
        RIGHT(
            REPLICATE('0', 15) +
            CAST(CAST(ROUND(ISNULL(monto_4ult, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
            15
        ) AS importe_cts15,
        LEFT(tipodocumento + numerodocumento + REPLICATE(' ', 20), 20) AS codigo_beneficiario,
        LEFT(numerodocumento + REPLICATE(' ', 15), 15) AS numdoc_fmt,
        LEFT(apellido1 + REPLICATE(' ', 20), 20) +
        LEFT(apellido2 + REPLICATE(' ', 20), 20) +
        LEFT(nombres + REPLICATE(' ', 20), 20) AS nombre_fmt
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
        '06' +
        @ref_cabecera +
        @fecha_envio +
        REPLICATE(' ', 9) +
        RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
        @importe_soles +
        @importe_dolares +
        LEFT(@codigo_empresa + REPLICATE(' ', 5), 5);

    /*
        Detalle tipo 02 (380 chars, Macro Pagos CTS servicio 06):
        02(2) + cod.beneficiario(20) + doc.pago(21) + fecha(8) + moneda abono(2)
        + monto(15) + filler(1) + abono cuenta(30) + tipo persona(1) + tipo doc(2)
        + num doc(15) + ape1(20)+ape2(20)+nombres(20) + moneda CTS(2) + monto CTS(15)
        + filler(6) + celular(40) + email(140)
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
                REPLICATE(' ', 21) +
                REPLICATE(' ', 8) +
                moneda_abono +
                importe15 +
                ' ' +
                bloque_abono +
                'P' +
                tipodocumento +
                numdoc_fmt +
                nombre_fmt +
                moneda_abono +
                importe_cts15 +
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
