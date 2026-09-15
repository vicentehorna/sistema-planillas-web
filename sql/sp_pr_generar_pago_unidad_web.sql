/*
    Genera TXT Telecrédito BCP para UNA unidad (Pago por Unidad / hm_alamo).
    Cuenta origen = SY_ReplicationUnit.bcpAccount de @par_replicationunit.
    Tipo cuenta origen fijo 'C'.
    Requiere #TelecreditoPersonas (person) con trabajadores de esa unidad.
    Planilla/proceso por Description; concepto por code/Description/FormulaCode.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_pago_unidad_web]
    @par_replicationunit VARCHAR(20),
    @payroll_desc        VARCHAR(100),
    @proceso_desc        VARCHAR(100),
    @par_period          VARCHAR(8),
    @par_concept         VARCHAR(40),
    @par_currency        VARCHAR(2) = 'LO',
    @par_paydate         DATETIME = NULL,
    @todos_bancos        CHAR(1) = 'N',
    @par_referencia      VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @par_replicationunit = LTRIM(RTRIM(ISNULL(@par_replicationunit, '')));
    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    SET @proceso_desc = LTRIM(RTRIM(ISNULL(@proceso_desc, '')));
    SET @par_period = LTRIM(RTRIM(ISNULL(@par_period, '')));
    SET @par_concept = LTRIM(RTRIM(ISNULL(@par_concept, '')));
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
    END;

    IF @par_replicationunit = ''
    BEGIN
        RAISERROR('Indique la unidad.', 16, 1);
        RETURN;
    END;

    DECLARE @moneda_txt      VARCHAR(4);
    DECLARE @tipo_proceso    CHAR(1);
    DECLARE @cuenta_origen   VARCHAR(20);
    DECLARE @tipo_cta_origen CHAR(1);
    DECLARE @ref_planilla    VARCHAR(40);
    DECLARE @total_reg       INT;
    DECLARE @monto_total     DECIMAL(18, 2);
    DECLARE @checksum        BIGINT;
    DECLARE @linea_cabecera  VARCHAR(500);
    DECLARE @cta_chk         VARCHAR(20);
    DECLARE @parte_chk       VARCHAR(30);

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN '1001' ELSE '0001' END;
    SET @tipo_cta_origen = 'C';

    SELECT @cuenta_origen = LEFT(LTRIM(RTRIM(ISNULL(ru.bcpAccount, ''))), 20)
    FROM SY_ReplicationUnit ru (NOLOCK)
    WHERE ru.ReplicationUnit = @par_replicationunit;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@cuenta_origen, ''))), '') IS NULL
    BEGIN
        RAISERROR('La unidad no tiene Nro Cuenta BCP configurada.', 16, 1);
        RETURN;
    END;

    SELECT TOP 1
        @tipo_proceso = LEFT(LTRIM(RTRIM(ISNULL(CAST(pt.subtype AS VARCHAR(10)), ''))), 1)
    FROM PR_ProcessType pt (NOLOCK)
    WHERE LTRIM(RTRIM(ISNULL(pt.Description, ''))) = @proceso_desc
    ORDER BY pt.Company;

    IF @tipo_proceso IS NULL OR @tipo_proceso = '' SET @tipo_proceso = '1';

    IF @par_referencia <> ''
        SET @ref_planilla = LEFT(@par_referencia, 40);
    ELSE
        SET @ref_planilla = LEFT('PLANILLA HABERES ' + @proceso_desc, 40);

    IF @ref_planilla IS NULL OR LTRIM(RTRIM(@ref_planilla)) = ''
        SET @ref_planilla = 'PLANILLA HABERES';

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #TelecreditoPersonas tp
        WHERE LTRIM(RTRIM(ISNULL(tp.person, ''))) <> ''
    ),
    Pagos AS (
        SELECT
            epc.company,
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc (NOLOCK)
            INNER JOIN PersonasSel ps ON ps.person = epc.person
            INNER JOIN PR_PayRollType pt (NOLOCK)
                ON pt.Company = epc.Company
               AND pt.PayRollType = epc.PayRollType
               AND LTRIM(RTRIM(ISNULL(pt.Description, ''))) = @payroll_desc
            INNER JOIN PR_ProcessType prt (NOLOCK)
                ON prt.Company = epc.Company
               AND prt.ProcessType = epc.ProcessType
               AND LTRIM(RTRIM(ISNULL(prt.Description, ''))) = @proceso_desc
            INNER JOIN PR_Concept pc (NOLOCK)
                ON pc.Company = epc.Company
               AND pc.Concept = epc.Concept
               AND (
                    LTRIM(RTRIM(ISNULL(pc.Concept, ''))) = @par_concept
                 OR LTRIM(RTRIM(ISNULL(pc.Description, ''))) = @par_concept
                 OR LTRIM(RTRIM(ISNULL(pc.FormulaCode, ''))) = @par_concept
               )
        WHERE epc.prperiod = @par_period
        GROUP BY epc.company, epc.person
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
                    THEN 'B'
                WHEN e.salarybank = m.creditobank
                    THEN LEFT(ISNULL(tat.abrev, 'A'), 1)
                ELSE 'B'
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
        FROM PR_Employee e (NOLOCK)
            INNER JOIN SY_Person sp (NOLOCK) ON sp.person = e.person
            INNER JOIN pr_mapping m (NOLOCK) ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person AND p.company = e.company
            INNER JOIN PersonasSel ps ON ps.person = e.person
            INNER JOIN PR_PayRollType pt2 (NOLOCK)
                ON pt2.Company = e.Company
               AND pt2.PayRollType = e.PayRollType
               AND LTRIM(RTRIM(ISNULL(pt2.Description, ''))) = @payroll_desc
            LEFT JOIN TE_accounttype tat ON tat.AccountType = e.SalaryAccountType
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        WHERE LTRIM(RTRIM(ISNULL(sp.ReplicationUnit, ''))) = @par_replicationunit
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

    IF @total_reg = 0
    BEGIN
        SELECT CAST(NULL AS INT) AS orden, CAST(NULL AS VARCHAR(500)) AS linea_txt WHERE 1 = 0;
        RETURN;
    END;

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
