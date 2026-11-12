/*
    Genera TXT Telecrédito CTS BCP para UNA unidad (Pago por Unidad CTS / hm_alamo).
    Cuenta origen = SY_ReplicationUnit.bcpAccount de @par_replicationunit.
    Layout hm_alamo (cabecera 125 / detalle 214), igual sp_pr_generar_telecreditocts_web:
      Cabecera: 1 | cantidad(6) | fecha | 'C' | moneda(4) | cuenta(20) | '6' | RUC(12) |
                monto | referencia(40) | checksum(15)
      Detalle:  2 | cuenta CTS(20) | tipodoc | doc(12) | 3 esp | nombre(75) |
                espacios(40) | espacios(20) | moneda | importe | '0001' | BASICO_CTS*4
    Requiere #TelecreditoPersonas (person) con trabajadores de esa unidad.
    Planilla por Description; proceso ShortName CTS; concepto PR_Mapping.CTSConcept.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_pagocts_unidad_web]
    @par_replicationunit VARCHAR(20),
    @payroll_desc        VARCHAR(100),
    @par_period          VARCHAR(8),
    @par_currency        VARCHAR(2) = 'LO',
    @par_paydate         DATETIME = NULL,
    @par_referencia      VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @par_replicationunit = LTRIM(RTRIM(ISNULL(@par_replicationunit, '')));
    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    SET @par_period = LTRIM(RTRIM(ISNULL(@par_period, '')));
    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    SET @par_currency = UPPER(@par_currency);
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
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

    IF @payroll_desc = '' OR @par_period = ''
    BEGIN
        RAISERROR('Indique tipo planilla y periodo.', 16, 1);
        RETURN;
    END;

    DECLARE @moneda_txt      VARCHAR(4);
    DECLARE @cuenta_origen   VARCHAR(20);
    DECLARE @ref_planilla    VARCHAR(40);
    DECLARE @total_reg       INT;
    DECLARE @total_cent      BIGINT;
    DECLARE @checksum        BIGINT;
    DECLARE @parte_chk       VARCHAR(30);
    DECLARE @ruc_empresa     VARCHAR(12);
    DECLARE @company_ruc     VARCHAR(10);

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN '1001' ELSE '0001' END;

    SELECT @cuenta_origen = LEFT(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(ru.bcpAccount, ''))), '-', ''), ' ', ''), 20)
    FROM SY_ReplicationUnit ru (NOLOCK)
    WHERE ru.ReplicationUnit = @par_replicationunit;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@cuenta_origen, ''))), '') IS NULL
    BEGIN
        RAISERROR('La unidad no tiene Nro Cuenta BCP configurada.', 16, 1);
        RETURN;
    END;

    IF @par_referencia <> ''
        SET @ref_planilla = LEFT(@par_referencia + REPLICATE(' ', 40), 40);
    ELSE
        SET @ref_planilla = REPLICATE(' ', 40);

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
               AND prt.ShortName = 'CTS'
            INNER JOIN PR_Mapping m (NOLOCK)
                ON m.Company = epc.Company
               AND m.CTSConcept = epc.Concept
        WHERE epc.prperiod = @par_period
        GROUP BY epc.company, epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    ),
    BasicoCts AS (
        SELECT
            epc.Company,
            epc.Person,
            MAX(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.ConceptValueEx, 0)
                    ELSE ISNULL(epc.ConceptValueLo, 0)
                END
            ) AS basico_cts
        FROM PR_EmployeePayRollConcept epc (NOLOCK)
            INNER JOIN PersonasSel ps ON ps.person = epc.Person
            INNER JOIN PR_Concept c (NOLOCK)
                ON c.Company = epc.Company
               AND c.Concept = epc.Concept
               AND c.FormulaCode = 'BASICO_CTS'
            INNER JOIN PR_ProcessType pt (NOLOCK)
                ON pt.Company = epc.Company
               AND pt.ProcessType = epc.ProcessType
               AND pt.ShortName = 'CTS'
            INNER JOIN PR_PayRollType prt (NOLOCK)
                ON prt.Company = epc.Company
               AND prt.PayRollType = epc.PayRollType
               AND LTRIM(RTRIM(ISNULL(prt.Description, ''))) = @payroll_desc
        WHERE epc.PRPeriod = @par_period
        GROUP BY epc.Company, epc.Person
    ),
    DetalleBase AS (
        SELECT
            e.company,
            e.person,
            LEFT(
                REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', ''),
                20
            ) AS cuenta,
            CASE
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('03', '04', '3', '4') THEN '3'
                WHEN ISNULL(pdt.PDT, '') IN ('06', '07', '6', '7') THEN '4'
                ELSE '1'
            END AS tipodoc_bcp,
            LEFT(LTRIM(RTRIM(
                COALESCE(
                    NULLIF(LTRIM(RTRIM(ISNULL(sp.DocumentNumberBcp, ''))), ''),
                    NULLIF(LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ''))), ''),
                    LTRIM(RTRIM(ISNULL(sp.Ruc, '')))
                )
            )), 12) AS dni,
            LEFT(LTRIM(RTRIM(
                ISNULL(sp.lastname1, '') + ' ' +
                ISNULL(sp.lastname2, '') + ' ' +
                ISNULL(sp.name1, '') + ' ' +
                ISNULL(sp.name2, '')
            )), 75) AS nombre,
            COALESCE(
                CASE
                    WHEN ects.Person IS NOT NULL THEN
                        CASE
                            WHEN @par_currency = 'EX'
                                THEN ISNULL(ects.AmountEx, 0) + ISNULL(ects.AmountInterestEx, 0)
                            ELSE ISNULL(ects.AmountLo, 0) + ISNULL(ects.AmountInterestLo, 0)
                        END
                    ELSE NULL
                END,
                p.importe,
                0
            ) AS importe,
            ISNULL(bas.basico_cts, 0) AS basico_cts
        FROM PR_Employee e (NOLOCK)
            INNER JOIN SY_Person sp (NOLOCK) ON sp.person = e.person
            INNER JOIN pr_mapping m (NOLOCK) ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person AND p.company = e.company
            INNER JOIN PersonasSel ps ON ps.person = e.person
            INNER JOIN PR_PayRollType pt2 (NOLOCK)
                ON pt2.Company = e.Company
               AND pt2.PayRollType = e.PayRollType
               AND LTRIM(RTRIM(ISNULL(pt2.Description, ''))) = @payroll_desc
            LEFT JOIN BasicoCts bas
                ON bas.Company = e.Company
               AND bas.Person = e.Person
            LEFT JOIN PR_EmployeeCTS ects
                ON ects.Company = e.Company
               AND ects.PayRollType = e.PayRollType
               AND ects.PRPeriod = @par_period
               AND ects.Person = e.Person
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        WHERE LTRIM(RTRIM(ISNULL(sp.ReplicationUnit, ''))) = @par_replicationunit
          AND ISNULL(m.creditobank, '') <> ''
          AND e.CTSBank = m.creditobank
          AND REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', '') <> ''
          AND ISNULL(NULLIF(LTRIM(RTRIM(e.CTSCurrency)), ''), 'LO') = @par_currency
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
        company,
        person,
        cuenta,
        tipodoc_bcp,
        dni,
        nombre,
        importe,
        CAST(ROUND(ISNULL(importe, 0) * 100, 0) AS BIGINT) AS cent,
        CAST(ROUND(ISNULL(basico_cts, 0) * 4 * 100, 0) AS BIGINT) AS cent_cts_anios
    INTO #Detalle
    FROM DetalleBase
    WHERE LTRIM(RTRIM(ISNULL(cuenta, ''))) <> '';

    SELECT @total_reg = COUNT(*), @total_cent = ISNULL(SUM(cent), 0) FROM #Detalle;

    IF @total_reg = 0
    BEGIN
        SELECT CAST(NULL AS INT) AS orden, CAST(NULL AS VARCHAR(500)) AS linea_txt WHERE 1 = 0;
        RETURN;
    END;

    /* RUC pagador: compañía con mayor importe en el archivo de la unidad. */
    SELECT TOP 1 @company_ruc = company
    FROM #Detalle
    GROUP BY company
    ORDER BY SUM(importe) DESC, company;

    SELECT TOP 1 @ruc_empresa = LEFT(LTRIM(RTRIM(ISNULL(c.Ruc, ''))) + REPLICATE(' ', 12), 12)
    FROM SY_Company c (NOLOCK)
    WHERE c.Company = @company_ruc;
    IF @ruc_empresa IS NULL SET @ruc_empresa = REPLICATE(' ', 12);

    /* Checksum: cargo (quitar 3) + abonos BCP (quitar 3). Longitud cargo fija 10 como formato alamo C. */
    SET @checksum = 0;
    IF LEN(@cuenta_origen) >= 4
    BEGIN
        SET @parte_chk = SUBSTRING(@cuenta_origen, 4, 10);
        IF @parte_chk NOT LIKE '%[^0-9]%' AND @parte_chk <> ''
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
            'C' +
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
GO
