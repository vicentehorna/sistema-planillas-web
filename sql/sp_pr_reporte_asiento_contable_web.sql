/*
    Reporte Asiento Contable (RPR024) — verificación cuenta contable por concepto.
    Equivalente al query legacy de PowerBuilder.

    Resultset 1: detalle cuenta/concepto (debe/haber)
                 Con @aplicar_distribucion='Y' usa lógica legacy sp_pr_asiento_distribuido:
                 detalle por trabajador + centro de costo (FlagSumType T → PR_DistribucionVoucher;
                 resto → CC del trabajador). Columnas: Cuenta, Concepto, Centro Costo, Código,
                 Trabajador, Estado, F.Cese, Debe, Haber.
    Resultset 2: problemas de configuración que explican descuadres
    Resultset 3: personas que explican el descuadre

    @person: opcional. Vacío/NULL = Todos; con valor = solo ese trabajador (Person).
    @aplicar_distribucion: 'N' (default) = asiento normal; 'Y' = prorrateo %.

    Usado por: POST /api/asientos/reporte-contable
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporte_asiento_contable_web]
    @company VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period VARCHAR(20),
    @currency VARCHAR(2) = 'LO',
    @person VARCHAR(20) = NULL,  /* vacío / NULL = Todos */
    @aplicar_distribucion CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @currency = UPPER(LTRIM(RTRIM(ISNULL(@currency, 'LO'))));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @aplicar_distribucion = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@aplicar_distribucion, 'N'))), 1));
    IF @aplicar_distribucion NOT IN ('Y', 'N') SET @aplicar_distribucion = 'N';
    IF @currency NOT IN ('LO', 'EX')
        SET @currency = 'LO';

    DECLARE @tipo_dist VARCHAR(2) = 'OT';
    IF @aplicar_distribucion = 'Y'
       AND EXISTS (
            SELECT 1
            FROM PR_DistribucionVoucher d (NOLOCK)
            WHERE d.company = @company
              AND (
                    d.period = @period
                 OR LEFT(LTRIM(RTRIM(ISNULL(d.period, ''))), 6) = LEFT(@period, 6)
              )
              AND LTRIM(RTRIM(ISNULL(d.tipo, ''))) = 'CC'
       )
        SET @tipo_dist = 'CC';

    /* -------- Resultset 1: asiento por cuenta/concepto (+ dist opcional) -------- */
    IF @aplicar_distribucion = 'Y'
    BEGIN
        /*
            Formato legacy sp_pr_asiento_distribuido:
            Cuenta | Concepto | Centro Costo | Código | Trabajador | Estado | F.Cese | Debe | Haber
            - FlagSumType <> 'T': importe íntegro al CC del trabajador (AC_CostCenter.Abbrev)
            - FlagSumType  = 'T': prorrateo por PR_DistribucionVoucher (tipo CC/OT)
        */
        SELECT
            PR.Description AS processname,
            P.Description AS payrolltypename,
            AC.Code AS account,
            AC.Name AS accountname,
            C.Description AS conceptname,
            ISNULL(NULLIF(LTRIM(RTRIM(CC.Abbrev)), ''), ISNULL(NULLIF(LTRIM(RTRIM(CC.Name)), ''), '')) AS costcentername,
            EPC.Person AS person,
            SY_Person.Name AS trabajador,
            CASE
                WHEN E.CeaseDate IS NOT NULL THEN 'Cesado'
                ELSE 'Activo'
            END AS status,
            CASE
                WHEN E.CeaseDate IS NULL THEN '00-00-0000'
                ELSE CONVERT(VARCHAR(10), E.CeaseDate, 105)
            END AS ceasedate,
            SUM(
                CASE
                    WHEN AC.Account = A.DebitAccount THEN mb.monto_base
                    ELSE 0
                END
            ) AS conceptvaluedebe,
            SUM(
                CASE
                    WHEN AC.Account = A.CreditAccount THEN mb.monto_base
                    ELSE 0
                END
            ) AS conceptvaluehaber
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
            ON EPC.Company = EP.Company
           AND EPC.PayRollType = EP.PayRollType
           AND EPC.ProcessType = EP.ProcessType
           AND EPC.PRPeriod = EP.PRPeriod
           AND EPC.Person = EP.Person
        INNER JOIN AC_CostCenter CC (NOLOCK)
            ON EP.CostCenter = CC.CostCenter
        INNER JOIN PR_PayRollType P (NOLOCK)
            ON P.PayRollType = EPC.PayRollType
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Concept = EPC.Concept
        INNER JOIN PR_Concepttype T (NOLOCK)
            ON T.Concepttype = C.Concepttype
        INNER JOIN PR_AccountProfileDetail A (NOLOCK)
            ON A.AccountProfile = EP.AccountProfile
           AND A.Concept = EPC.Concept
           AND A.ProcessType = EPC.ProcessType
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Company = @company
           AND E.Person = EPC.Person
        INNER JOIN AC_Account AC (NOLOCK)
            ON AC.Account = A.DebitAccount
            OR AC.Account = A.CreditAccount
        INNER JOIN PR_ProcessType PR (NOLOCK)
            ON PR.ProcessType = EPC.ProcessType
        INNER JOIN SY_Person (NOLOCK)
            ON EPC.Person = SY_Person.Person
        CROSS APPLY (
            SELECT
                CASE
                    WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                    ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                END AS monto_base
        ) mb
        WHERE EPC.Company = @company
          AND EPC.PRPeriod = @period
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND (@person = '' OR EPC.Person = @person)
          AND EPC.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(T.ShortName)) IN ('I', 'D', 'A', 'T', 'G', 'X')
          AND LTRIM(RTRIM(ISNULL(A.FlagSumType, ''))) <> 'T'
        GROUP BY
            PR.Description,
            P.Description,
            AC.Code,
            AC.Name,
            C.Description,
            ISNULL(NULLIF(LTRIM(RTRIM(CC.Abbrev)), ''), ISNULL(NULLIF(LTRIM(RTRIM(CC.Name)), ''), '')),
            EPC.Person,
            SY_Person.Name,
            E.Status,
            E.CeaseDate
        HAVING
            SUM(CASE WHEN AC.Account = A.DebitAccount THEN mb.monto_base ELSE 0 END) <> 0
            OR SUM(CASE WHEN AC.Account = A.CreditAccount THEN mb.monto_base ELSE 0 END) <> 0

        UNION ALL

        SELECT
            PR.Description AS processname,
            P.Description AS payrolltypename,
            AC.Code AS account,
            AC.Name AS accountname,
            C.Description AS conceptname,
            ISNULL(NULLIF(LTRIM(RTRIM(D.codigo)), ''), '') AS costcentername,
            EPC.Person AS person,
            SY_Person.Name AS trabajador,
            CASE
                WHEN E.CeaseDate IS NOT NULL THEN 'Cesado'
                ELSE 'Activo'
            END AS status,
            CASE
                WHEN E.CeaseDate IS NULL THEN '00-00-0000'
                ELSE CONVERT(VARCHAR(10), E.CeaseDate, 105)
            END AS ceasedate,
            SUM(
                CASE
                    WHEN AC.Account = A.DebitAccount THEN md.monto_dist
                    ELSE 0
                END
            ) AS conceptvaluedebe,
            SUM(
                CASE
                    WHEN AC.Account = A.CreditAccount THEN md.monto_dist
                    ELSE 0
                END
            ) AS conceptvaluehaber
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_DistribucionVoucher D (NOLOCK)
            ON D.dni = EPC.Person
           AND D.company = EPC.Company
           AND LTRIM(RTRIM(ISNULL(D.tipo, @tipo_dist))) = @tipo_dist
           AND (
                    D.period = @period
                 OR (
                        NOT EXISTS (
                            SELECT 1
                            FROM PR_DistribucionVoucher dx (NOLOCK)
                            WHERE dx.dni = EPC.Person
                              AND dx.company = EPC.Company
                              AND dx.period = @period
                              AND LTRIM(RTRIM(ISNULL(dx.tipo, ''))) = @tipo_dist
                        )
                    AND LEFT(LTRIM(RTRIM(ISNULL(D.period, ''))), 6) = LEFT(@period, 6)
                 )
               )
        INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
            ON EPC.Company = EP.Company
           AND EPC.PayRollType = EP.PayRollType
           AND EPC.ProcessType = EP.ProcessType
           AND EPC.PRPeriod = EP.PRPeriod
           AND EPC.Person = EP.Person
        INNER JOIN PR_PayRollType P (NOLOCK)
            ON P.PayRollType = EPC.PayRollType
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Concept = EPC.Concept
        INNER JOIN PR_Concepttype T (NOLOCK)
            ON T.Concepttype = C.Concepttype
        INNER JOIN PR_AccountProfileDetail A (NOLOCK)
            ON A.AccountProfile = EP.AccountProfile
           AND A.Concept = EPC.Concept
           AND A.ProcessType = EPC.ProcessType
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Company = @company
           AND E.Person = EPC.Person
        INNER JOIN AC_Account AC (NOLOCK)
            ON AC.Account = A.DebitAccount
            OR AC.Account = A.CreditAccount
        INNER JOIN PR_ProcessType PR (NOLOCK)
            ON PR.ProcessType = EPC.ProcessType
        INNER JOIN SY_Person (NOLOCK)
            ON EPC.Person = SY_Person.Person
        CROSS APPLY (
            SELECT
                CASE
                    WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                    ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                END AS monto_base
        ) mb
        CROSS APPLY (
            SELECT CONVERT(DECIMAL(18, 2),
                ROUND(
                    mb.monto_base
                    * (ISNULL(D.valor, CONVERT(DECIMAL(18, 4), 100)) / CONVERT(DECIMAL(18, 4), 100)),
                    2
                )
            ) AS monto_dist
        ) md
        WHERE EPC.Company = @company
          AND EPC.PRPeriod = @period
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND (@person = '' OR EPC.Person = @person)
          AND EPC.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(T.ShortName)) IN ('I', 'D', 'A', 'T', 'G', 'X')
          AND LTRIM(RTRIM(ISNULL(A.FlagSumType, ''))) = 'T'
        GROUP BY
            PR.Description,
            P.Description,
            AC.Code,
            AC.Name,
            C.Description,
            ISNULL(NULLIF(LTRIM(RTRIM(D.codigo)), ''), ''),
            EPC.Person,
            SY_Person.Name,
            E.Status,
            E.CeaseDate
        HAVING
            SUM(CASE WHEN AC.Account = A.DebitAccount THEN md.monto_dist ELSE 0 END) <> 0
            OR SUM(CASE WHEN AC.Account = A.CreditAccount THEN md.monto_dist ELSE 0 END) <> 0
        ORDER BY
            processname,
            trabajador,
            account,
            conceptname,
            costcentername;
    END
    ELSE
    BEGIN
        SELECT
            PR.Description AS processname,
            P.Description AS payrolltypename,
            AC.Code AS account,
            AC.Name AS accountname,
            C.Description AS conceptname,
            CAST('' AS VARCHAR(50)) AS costcentername,
            CAST('' AS VARCHAR(20)) AS person,
            CAST('' AS VARCHAR(120)) AS trabajador,
            CAST('' AS VARCHAR(20)) AS status,
            CAST('' AS VARCHAR(10)) AS ceasedate,
            SUM(
                CASE
                    WHEN AC.Account = A.DebitAccount THEN
                        CASE
                            WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                            ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                        END
                    ELSE 0
                END
            ) AS conceptvaluedebe,
            SUM(
                CASE
                    WHEN AC.Account = A.CreditAccount THEN
                        CASE
                            WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                            ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                        END
                    ELSE 0
                END
            ) AS conceptvaluehaber
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
            ON EPC.Company = EP.Company
           AND EPC.PayRollType = EP.PayRollType
           AND EPC.ProcessType = EP.ProcessType
           AND EPC.PRPeriod = EP.PRPeriod
           AND EPC.Person = EP.Person
        INNER JOIN PR_PayRollType P (NOLOCK)
            ON P.PayRollType = EPC.PayRollType
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Concept = EPC.Concept
        INNER JOIN PR_Concepttype T (NOLOCK)
            ON T.Concepttype = C.Concepttype
        INNER JOIN PR_AccountProfileDetail A (NOLOCK)
            ON A.AccountProfile = EP.AccountProfile
           AND A.Concept = EPC.Concept
           AND A.ProcessType = EPC.ProcessType
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Company = @company
           AND E.Person = EPC.Person
        INNER JOIN AC_Account AC (NOLOCK)
            ON AC.Account = A.DebitAccount
            OR AC.Account = A.CreditAccount
        INNER JOIN PR_ProcessType PR (NOLOCK)
            ON PR.ProcessType = EPC.ProcessType
        INNER JOIN SY_Person (NOLOCK)
            ON EPC.Person = SY_Person.Person
        WHERE EPC.Company = @company
          AND EPC.PRPeriod = @period
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND (@person = '' OR EPC.Person = @person)
          AND EPC.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(T.ShortName)) IN ('I', 'D', 'A', 'T', 'G', 'X')
        GROUP BY
            PR.Description,
            P.Description,
            AC.Code,
            AC.Name,
            C.Description
        HAVING
            SUM(
                CASE
                    WHEN AC.Account = A.DebitAccount THEN
                        CASE
                            WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                            ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                        END
                    ELSE 0
                END
            ) <> 0
            OR SUM(
                CASE
                    WHEN AC.Account = A.CreditAccount THEN
                        CASE
                            WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                            ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                        END
                    ELSE 0
                END
            ) <> 0
        ORDER BY
            PR.Description,
            AC.Name,
            P.Description,
            AC.Code,
            C.Description;
    END

    /* -------- Resultset 2: motivos de diferencia / config -------- */
    ;WITH base AS (
        SELECT
            EPC.Concept,
            C.Description AS conceptname,
            LTRIM(RTRIM(T.ShortName)) AS tiposhort,
            ISNULL(T.Description, '') AS tiponame,
            CASE
                WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
            END AS monto,
            A.DebitAccount,
            A.CreditAccount,
            dac.Code AS debitcode,
            cac.Code AS creditcode,
            CASE WHEN A.Concept IS NULL THEN 1 ELSE 0 END AS sin_apd
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
            ON EPC.Company = EP.Company
           AND EPC.PayRollType = EP.PayRollType
           AND EPC.ProcessType = EP.ProcessType
           AND EPC.PRPeriod = EP.PRPeriod
           AND EPC.Person = EP.Person
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Concept = EPC.Concept
        INNER JOIN PR_Concepttype T (NOLOCK)
            ON T.Concepttype = C.Concepttype
        LEFT JOIN PR_AccountProfileDetail A (NOLOCK)
            ON A.AccountProfile = EP.AccountProfile
           AND A.Concept = EPC.Concept
           AND A.ProcessType = EPC.ProcessType
        LEFT JOIN AC_Account dac (NOLOCK) ON dac.Account = A.DebitAccount
        LEFT JOIN AC_Account cac (NOLOCK) ON cac.Account = A.CreditAccount
        WHERE EPC.Company = @company
          AND EPC.PRPeriod = @period
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND (@person = '' OR EPC.Person = @person)
          AND EPC.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(T.ShortName)) IN ('I', 'D', 'A')
          AND ABS(
                CASE
                    WHEN @currency = 'EX' THEN ISNULL(EPC.ConceptValueEx, 0)
                    ELSE ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0))
                END
              ) > 0.0001
    ),
    agg AS (
        SELECT
            Concept,
            conceptname,
            tiposhort,
            MAX(tiponame) AS tiponame,
            SUM(monto) AS total_monto,
            MAX(sin_apd) AS sin_apd,
            MAX(CASE WHEN DebitAccount IS NOT NULL AND LTRIM(RTRIM(DebitAccount)) <> '' THEN 1 ELSE 0 END) AS has_debe,
            MAX(CASE WHEN CreditAccount IS NOT NULL AND LTRIM(RTRIM(CreditAccount)) <> '' THEN 1 ELSE 0 END) AS has_haber,
            MAX(debitcode) AS debitcode,
            MAX(creditcode) AS creditcode
        FROM base
        GROUP BY Concept, conceptname, tiposhort
    )
    SELECT
        Concept AS concept,
        conceptname,
        tiposhort,
        tiponame,
        total_monto AS monto,
        debitcode AS cuenta_debe,
        creditcode AS cuenta_haber,
        CASE
            WHEN sin_apd = 1 OR (has_debe = 0 AND has_haber = 0) THEN
                CASE tiposhort
                    WHEN 'D' THEN 'Descuento sin cuenta contable en Configurar Conceptos (falta HABER, p.ej. 401731)'
                    WHEN 'A' THEN 'Aporte sin cuenta contable en Configurar Conceptos'
                    WHEN 'I' THEN 'Ingreso sin cuenta contable en Configurar Conceptos'
                    ELSE 'Sin cuenta contable asociada en Configurar Conceptos'
                END
            WHEN tiposhort = 'I' AND has_haber = 1 AND has_debe = 0 THEN
                'Ingreso configurado solo en HABER (falta cuenta DEBE)'
            WHEN tiposhort = 'I' AND has_debe = 1 AND has_haber = 0
                 AND (
                    UPPER(conceptname) LIKE '%DEVOLUC%'
                    OR UPPER(ISNULL(debitcode, '')) LIKE '4017%'
                 ) THEN
                'Devolución/ingreso solo en DEBE (falta cuenta HABER, p.ej. Neto 415401)'
            WHEN tiposhort = 'D' AND has_debe = 1 AND has_haber = 0 THEN
                'Descuento configurado solo en DEBE (falta cuenta HABER)'
            WHEN tiposhort = 'A' AND has_debe = 1 AND has_haber = 0 THEN
                'Aporte configurado solo en DEBE (falta cuenta HABER)'
            WHEN tiposhort = 'A' AND has_haber = 1 AND has_debe = 0 THEN
                'Aporte configurado solo en HABER (falta cuenta DEBE)'
            ELSE
                'Configuración de cuentas incompleta'
            END AS problema,
        CASE
            /* Lado incorrecto: el monto aparece en el lado opuesto → afecta 2x la diferencia */
            WHEN tiposhort = 'I' AND has_haber = 1 AND has_debe = 0 THEN ROUND(2 * total_monto, 2)
            WHEN tiposhort = 'D' AND has_debe = 1 AND has_haber = 0 THEN ROUND(2 * total_monto, 2)
            WHEN tiposhort = 'A' AND ((has_debe = 1 AND has_haber = 0) OR (has_haber = 1 AND has_debe = 0))
                THEN ROUND(ABS(total_monto), 2)
            /* Devolución solo DEBE o sin cuenta: falta contrapartida → 1x */
            WHEN tiposhort = 'I' AND has_debe = 1 AND has_haber = 0
                 AND (
                    UPPER(conceptname) LIKE '%DEVOLUC%'
                    OR UPPER(ISNULL(debitcode, '')) LIKE '4017%'
                 ) THEN ROUND(ABS(total_monto), 2)
            WHEN sin_apd = 1 OR (has_debe = 0 AND has_haber = 0) THEN ROUND(ABS(total_monto), 2)
            ELSE ROUND(ABS(total_monto), 2)
        END AS impacto_estimado
    FROM agg
    WHERE
        /* Lado incorrecto: causa típica de diferencia 2x */
        (tiposhort = 'I' AND has_haber = 1 AND has_debe = 0)
        OR (tiposhort = 'D' AND has_debe = 1 AND has_haber = 0)
        /* Aporte incompleto (debe faltar haber o viceversa) */
        OR (
            tiposhort = 'A'
            AND (
                (has_debe = 1 AND has_haber = 0)
                OR (has_haber = 1 AND has_debe = 0)
            )
        )
        /* Devolución de quinta u homólogos: ingreso solo en DEBE sobre 4017xx */
        OR (
            tiposhort = 'I'
            AND has_debe = 1 AND has_haber = 0
            AND (
                UPPER(conceptname) LIKE '%DEVOLUC%'
                OR UPPER(ISNULL(debitcode, '')) LIKE '4017%'
            )
        )
        /* Sin cuenta: ingresos, aportes y descuentos (p.ej. retención 5ta en liquidación) */
        OR (
            tiposhort IN ('I', 'A', 'D')
            AND (sin_apd = 1 OR (has_debe = 0 AND has_haber = 0))
        )
    ORDER BY impacto_estimado DESC, conceptname;

    /* -------- Resultset 3: descuadre / neto por trabajador -------- */
    ;WITH montos AS (
        SELECT
            EPC.Person,
            LTRIM(RTRIM(T.ShortName)) AS tiposhort,
            UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) AS formulacode,
            C.Description AS conceptname,
            CASE
                WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
            END AS monto
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Concept = EPC.Concept
        INNER JOIN PR_Concepttype T (NOLOCK)
            ON T.Concepttype = C.Concepttype
        WHERE EPC.Company = @company
          AND EPC.PRPeriod = @period
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND (@person = '' OR EPC.Person = @person)
          AND EPC.FlagIsMonetary = 'Y'
          AND ABS(
                CASE
                    WHEN @currency = 'EX' THEN ISNULL(EPC.ConceptValueEx, 0)
                    ELSE ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0))
                END
              ) > 0.0001
    ),
    id_agg AS (
        SELECT
            Person,
            SUM(CASE WHEN tiposhort = 'I' THEN monto ELSE 0 END) AS ingresos,
            SUM(CASE WHEN tiposhort = 'D' THEN monto ELSE 0 END) AS descuentos,
            SUM(CASE WHEN formulacode = 'NETO' THEN monto ELSE 0 END) AS neto_formula,
            MAX(CASE WHEN formulacode = 'NETO' THEN 1 ELSE 0 END) AS tiene_neto
        FROM montos
        GROUP BY Person
    ),
    asiento AS (
        SELECT
            EPC.Person,
            SUM(
                CASE
                    WHEN AC.Account = A.DebitAccount THEN
                        CASE
                            WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                            ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                        END
                    ELSE 0
                END
            ) AS asiento_debe,
            SUM(
                CASE
                    WHEN AC.Account = A.CreditAccount THEN
                        CASE
                            WHEN @currency = 'EX' THEN ROUND(ISNULL(EPC.ConceptValueEx, 0), 2)
                            ELSE ROUND(ISNULL(EPC.ConceptValueLo, ISNULL(EPC.ConceptValue, 0)), 2)
                        END
                    ELSE 0
                END
            ) AS asiento_haber
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
            ON EPC.Company = EP.Company
           AND EPC.PayRollType = EP.PayRollType
           AND EPC.ProcessType = EP.ProcessType
           AND EPC.PRPeriod = EP.PRPeriod
           AND EPC.Person = EP.Person
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Concept = EPC.Concept
        INNER JOIN PR_Concepttype T (NOLOCK)
            ON T.Concepttype = C.Concepttype
        INNER JOIN PR_AccountProfileDetail A (NOLOCK)
            ON A.AccountProfile = EP.AccountProfile
           AND A.Concept = EPC.Concept
           AND A.ProcessType = EPC.ProcessType
        INNER JOIN AC_Account AC (NOLOCK)
            ON AC.Account = A.DebitAccount
            OR AC.Account = A.CreditAccount
        WHERE EPC.Company = @company
          AND EPC.PRPeriod = @period
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND (@person = '' OR EPC.Person = @person)
          AND EPC.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(T.ShortName)) IN ('I', 'D', 'A', 'T', 'G', 'X')
        GROUP BY EPC.Person
    ),
    topd AS (
        SELECT
            Person,
            conceptname,
            monto,
            ROW_NUMBER() OVER (PARTITION BY Person ORDER BY monto DESC, conceptname) AS rn
        FROM montos
        WHERE tiposhort = 'D'
    ),
    topd_agg AS (
        SELECT
            Person,
            STUFF((
                SELECT TOP 5
                    '; ' + t2.conceptname + ' ' + CONVERT(VARCHAR(32), CAST(t2.monto AS DECIMAL(18, 2)))
                FROM topd t2
                WHERE t2.Person = t1.Person
                  AND t2.rn <= 5
                ORDER BY t2.rn
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS top_descuentos
        FROM topd t1
        WHERE t1.rn = 1
        GROUP BY Person
    ),
    joined AS (
        SELECT
            i.Person,
            ROUND(ISNULL(i.ingresos, 0), 2) AS ingresos,
            ROUND(ISNULL(i.descuentos, 0), 2) AS descuentos,
            ROUND(ISNULL(i.ingresos, 0) - ISNULL(i.descuentos, 0), 2) AS neto_teorico,
            ROUND(ISNULL(i.neto_formula, 0), 2) AS neto_formula,
            CASE WHEN ISNULL(i.tiene_neto, 0) = 1 THEN 'Y' ELSE 'N' END AS tiene_neto,
            ROUND(ISNULL(a.asiento_debe, 0), 2) AS asiento_debe,
            ROUND(ISNULL(a.asiento_haber, 0), 2) AS asiento_haber,
            ROUND(ISNULL(a.asiento_debe, 0) - ISNULL(a.asiento_haber, 0), 2) AS asiento_diff,
            ISNULL(td.top_descuentos, '') AS top_descuentos
        FROM id_agg i
        LEFT JOIN asiento a ON a.Person = i.Person
        LEFT JOIN topd_agg td ON td.Person = i.Person
    )
    SELECT
        j.Person AS person,
        LTRIM(RTRIM(
            LTRIM(RTRIM(ISNULL(SP.LastName1, ''))) + ' '
            + LTRIM(RTRIM(ISNULL(SP.LastName2, ''))) + ' '
            + LTRIM(RTRIM(ISNULL(SP.Name1, ''))) + ' '
            + LTRIM(RTRIM(ISNULL(SP.Name2, '')))
        )) AS person_name,
        j.ingresos,
        j.descuentos,
        j.neto_teorico,
        j.neto_formula,
        j.tiene_neto,
        j.asiento_debe,
        j.asiento_haber,
        j.asiento_diff,
        j.top_descuentos,
        CASE
            WHEN ABS(j.asiento_diff) >= 0.005
                 AND j.neto_teorico < -0.005
                 AND (j.tiene_neto = 'N' OR ABS(j.neto_formula) < 0.005) THEN
                'Neto teórico negativo (I−D) y sin Neto a recibir: el asiento de este trabajador queda descuadrado'
            WHEN ABS(j.asiento_diff) >= 0.005
                 AND j.neto_teorico < -0.005 THEN
                'Neto teórico negativo (I−D); el asiento de este trabajador no cuadra'
            WHEN ABS(j.asiento_diff) >= 0.005
                 AND ABS(j.neto_teorico - j.neto_formula) >= 0.01
                 AND j.tiene_neto = 'Y' THEN
                'Asiento descuadrado: Neto registrado distinto del neto teórico (I−D)'
            WHEN ABS(j.asiento_diff) >= 0.005 THEN
                'Asiento de este trabajador no cuadra (Debe − Haber)'
            WHEN j.neto_teorico < -0.005
                 AND (j.tiene_neto = 'N' OR ABS(j.neto_formula) < 0.005) THEN
                'Neto teórico negativo (I−D) y sin concepto Neto a recibir (descuentos > ingresos)'
            ELSE
                'Revisar conceptos del trabajador'
        END AS causa
    FROM joined j
    LEFT JOIN SY_Person SP (NOLOCK) ON SP.Person = j.Person
    WHERE
        ABS(j.asiento_diff) >= 0.005
        OR (
            j.neto_teorico < -0.005
            AND (j.tiene_neto = 'N' OR ABS(j.neto_formula) < 0.005)
        )
    ORDER BY
        ABS(j.asiento_diff) DESC,
        j.neto_teorico ASC,
        j.Person;
END
GO
