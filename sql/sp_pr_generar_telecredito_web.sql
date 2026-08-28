/*
    Genera líneas del archivo Telecrédito BCP (cabecera tipo 1 + detalle tipo 2).
    Requiere tabla temporal #TelecreditoPersonas (person) creada por la app web
    con los trabajadores seleccionados antes de ejecutar este SP.
    @todos_bancos: N = solo cuenta propia BCP/creditobank; Y = propia + interbancarios (CCI).
    @par_referencia: texto cabecera TXT (40 chars). Si vacío, usa PLANILLA HABERES + proceso.
    Cuenta interbancaria (abrev B / descripción INTERBANCARIA) → siempre CCI (SocialAssistanceNumber) y tipo I,
    aunque el banco del trabajador coincida con creditobank.
    Mismo banco y cuenta propia → SalaryAccount (A/M/C/P); otro banco → CCI (I).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_telecredito_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @todos_bancos    CHAR(1) = 'N',
    @par_referencia  VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';
    SET @par_referencia = LTRIM(RTRIM(ISNULL(@par_referencia, '')));

    IF OBJECT_ID('tempdb..#TelecreditoPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #TelecreditoPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @moneda_txt      VARCHAR(4);
    DECLARE @tipo_proceso    CHAR(1);
    DECLARE @cuenta_origen   VARCHAR(20);
    DECLARE @tipo_cta_origen CHAR(1);
    DECLARE @ref_planilla    VARCHAR(40);
    DECLARE @concepto_desc   VARCHAR(40);
    DECLARE @total_reg       INT;
    DECLARE @monto_total     DECIMAL(18, 2);
    DECLARE @checksum        BIGINT;
    DECLARE @linea_cabecera  VARCHAR(500);
    DECLARE @cta_chk         VARCHAR(20);
    DECLARE @parte_chk       VARCHAR(30);

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN '1001' ELSE '0001' END;

    SELECT @concepto_desc = LTRIM(RTRIM(ISNULL(pc.Description, @par_concept)))
    FROM PR_Concept pc
    WHERE pc.Company = @par_company
      AND pc.Concept = @par_concept;

    SELECT @cuenta_origen = LEFT(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), 20)
    FROM TE_BankAccount ba
    WHERE ba.Company = @par_company
      AND ba.Bank = (SELECT CreditoBank FROM PR_Mapping WHERE Company = @par_company)
      AND ba.accountcurrency = @par_currency;

    SELECT @tipo_cta_origen = LEFT(ISNULL(tat.abrev, 'C'), 1)
    FROM te_accounttype tat
    WHERE tat.AccountType = (
        SELECT SalaryAccountType FROM PR_Mapping WHERE Company = @par_company
    );

    SELECT
        @tipo_proceso = LEFT(LTRIM(RTRIM(ISNULL(CAST(pt.subtype AS VARCHAR(10)), ''))), 1),
        @ref_planilla = LEFT(
            'PLANILLA HABERES ' + LTRIM(RTRIM(ISNULL(pt.Description, ISNULL(pt.ShortName, '')))),
            40
        )
    FROM PR_ProcessType pt
    WHERE pt.ProcessType = @par_processtype;

    IF @tipo_proceso IS NULL OR @tipo_proceso = '' SET @tipo_proceso = '1';
    IF @par_referencia <> ''
        SET @ref_planilla = LEFT(@par_referencia, 40);
    IF @ref_planilla IS NULL OR LTRIM(RTRIM(@ref_planilla)) = '' SET @ref_planilla = 'PLANILLA HABERES';
    IF @tipo_cta_origen IS NULL OR @tipo_cta_origen = '' SET @tipo_cta_origen = 'C';

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #TelecreditoPersonas tp
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
            LEFT(
                LTRIM(RTRIM(
                    CASE
                        WHEN ISNULL(tat.abrev, '') = 'B'
                             OR UPPER(ISNULL(tat.description, '')) LIKE '%INTERBANCARIA%'
                            THEN ISNULL(e.socialassistancenumber, '')
                        WHEN e.salarybank = m.creditobank
                            THEN ISNULL(e.salaryaccount, '')
                        ELSE ISNULL(e.socialassistancenumber, '')
                    END
                )),
                20
            ) AS cuenta,
            CASE
                WHEN ISNULL(tat.abrev, '') = 'B'
                     OR UPPER(ISNULL(tat.description, '')) LIKE '%INTERBANCARIA%'
                    THEN 'I'
                WHEN e.salarybank = m.creditobank
                    THEN LEFT(ISNULL(tat.abrev, 'A'), 1)
                ELSE 'I'
            END AS tipocuenta,
            CASE
                WHEN ISNULL(pdt.PDT, '') = '01' THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('03', '04') THEN '3'
                WHEN ISNULL(pdt.PDT, '') = '07' THEN '4'
                WHEN ISNULL(pdt.PDT, '') = '1' THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('3', '4') THEN '3'
                ELSE '1'
            END AS tipodocumento,
            LEFT(LTRIM(RTRIM(
                CASE
                    WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                    ELSE sp.DocumentNumber
                END
            )), 12) AS numerodocumento,
            LEFT(LTRIM(RTRIM(
                ISNULL(sp.lastname1, '') + ' ' +
                ISNULL(sp.lastname2, '') + ' ' +
                ISNULL(sp.name1, '') + ' ' +
                ISNULL(sp.name2, '')
            )), 75) AS nombre,
            LEFT(LTRIM(RTRIM(
                'Referencia Beneficiario ' + LTRIM(RTRIM(
                    CASE
                        WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                        ELSE sp.DocumentNumber
                    END
                ))
            )), 40) AS refbeneficiario,
            LEFT(LTRIM(RTRIM(
                'Ref Emp ' + LTRIM(RTRIM(
                    CASE
                        WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                        ELSE sp.DocumentNumber
                    END
                ))
            )), 20) AS refempresa,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN TE_accounttype tat ON tat.AccountType = e.SalaryAccountType
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND ISNULL(m.creditobank, '') <> ''
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
    )
    SELECT
        person,
        cuenta,
        tipocuenta,
        tipodocumento,
        numerodocumento,
        nombre,
        refbeneficiario,
        refempresa,
        importe,
        RIGHT(REPLICATE('0', 14) + CAST(CAST(ROUND(ISNULL(importe, 0), 2, 0) AS BIGINT) AS VARCHAR(20)), 14) +
        '.' +
        RIGHT(
            '00' + CAST(
                ABS(
                    CAST(ROUND(ISNULL(importe, 0) * 100, 0) AS BIGINT) -
                    CAST(ROUND(ISNULL(importe, 0), 2, 0) AS BIGINT) * 100
                ) AS VARCHAR(3)
            ),
            2
        ) AS importe_fmt
    INTO #Detalle
    FROM DetalleBase
    WHERE LTRIM(RTRIM(ISNULL(cuenta, ''))) <> '';

    SELECT @total_reg = COUNT(*) FROM #Detalle;
    SELECT @monto_total = ISNULL(SUM(importe), 0) FROM #Detalle;

    /*
        Checksum BCP (pos. 99-113): suma numérica de la parte útil de cada cuenta.
        Cuenta empresa: RIGHT(cuenta, LEN(cuenta) - 3).
        Cuentas empleado tipo A/M/C: RIGHT(cuenta, LEN(cuenta) - 3).
        Otros tipos: RIGHT(cuenta, 10).
    */
    SET @checksum = 0;
    SET @cta_chk = LTRIM(RTRIM(ISNULL(@cuenta_origen, '')));

    IF LEN(@cta_chk) > 3
    BEGIN
        SET @parte_chk = LTRIM(RTRIM(SUBSTRING(@cta_chk, 4, LEN(@cta_chk) - 3)));
        IF @parte_chk <> '' AND ISNUMERIC(@parte_chk) = 1
            SET @checksum = @checksum + CAST(@parte_chk AS BIGINT);
    END;

    SELECT @checksum = @checksum + ISNULL(SUM(
        CASE
            WHEN LTRIM(RTRIM(ISNULL(cuenta, ''))) = '' THEN CAST(0 AS BIGINT)
            WHEN tipocuenta IN ('A', 'M', 'C') THEN
                CASE
                    WHEN LEN(LTRIM(RTRIM(cuenta))) > 3 THEN
                        CASE
                            WHEN ISNUMERIC(LTRIM(RTRIM(SUBSTRING(LTRIM(RTRIM(cuenta)), 4, LEN(LTRIM(RTRIM(cuenta))) - 3)))) = 1
                            THEN CAST(LTRIM(RTRIM(SUBSTRING(LTRIM(RTRIM(cuenta)), 4, LEN(LTRIM(RTRIM(cuenta))) - 3))) AS BIGINT)
                            ELSE CAST(0 AS BIGINT)
                        END
                    ELSE CAST(0 AS BIGINT)
                END
            ELSE
                CASE
                    WHEN ISNUMERIC(LTRIM(RTRIM(RIGHT(LTRIM(RTRIM(cuenta)), 10)))) = 1
                    THEN CAST(LTRIM(RTRIM(RIGHT(LTRIM(RTRIM(cuenta)), 10))) AS BIGINT)
                    ELSE CAST(0 AS BIGINT)
                END
        END
    ), 0)
    FROM #Detalle;

    SET @linea_cabecera =
        '1' +
        RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
        CONVERT(VARCHAR(8), @par_paydate, 112) +
        @tipo_proceso +
        @tipo_cta_origen +
        @moneda_txt +
        LEFT(ISNULL(@cuenta_origen, '') + REPLICATE(' ', 20), 20) +
        RIGHT(REPLICATE('0', 14) + CAST(CAST(ROUND(ISNULL(@monto_total, 0), 2, 0) AS BIGINT) AS VARCHAR(20)), 14) +
        '.' +
        RIGHT(
            '00' + CAST(
                ABS(
                    CAST(ROUND(ISNULL(@monto_total, 0) * 100, 0) AS BIGINT) -
                    CAST(ROUND(ISNULL(@monto_total, 0), 2, 0) AS BIGINT) * 100
                ) AS VARCHAR(3)
            ),
            2
        ) +
        LEFT(ISNULL(@ref_planilla, '') + REPLICATE(' ', 40), 40) +
        RIGHT(REPLICATE('0', 15) + CAST(ISNULL(@checksum, 0) AS VARCHAR(20)), 15);

    SELECT orden, linea_txt
    FROM (
        SELECT 0 AS orden, @linea_cabecera AS linea_txt
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY nombre, person) AS orden,
            '2' +
            tipocuenta +
            LEFT(cuenta + REPLICATE(' ', 20), 20) +
            tipodocumento +
            LEFT(numerodocumento + REPLICATE(' ', 12), 12) +
            '   ' +
            LEFT(nombre + REPLICATE(' ', 75), 75) +
            LEFT(refbeneficiario + REPLICATE(' ', 40), 40) +
            LEFT(refempresa + REPLICATE(' ', 20), 20) +
            @moneda_txt +
            importe_fmt +
            'S' AS linea_txt
        FROM #Detalle
    ) AS lineas
    ORDER BY orden;
END
GO
