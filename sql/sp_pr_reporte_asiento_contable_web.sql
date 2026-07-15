/*
    Reporte Asiento Contable (RPR024) — verificación cuenta contable por concepto.
    Equivalente al query legacy de PowerBuilder.

    Resultset 1: detalle cuenta/concepto (debe/haber)
    Resultset 2: problemas de configuración que explican descuadres
                 (concepto sin cuenta o cuenta en el lado incorrecto)

    Usado por: POST /api/asientos/reporte-contable
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporte_asiento_contable_web]
    @company VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period VARCHAR(20),
    @currency VARCHAR(2) = 'LO'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @currency = UPPER(LTRIM(RTRIM(ISNULL(@currency, 'LO'))));
    IF @currency NOT IN ('LO', 'EX')
        SET @currency = 'LO';

    /* -------- Resultset 1: asiento por cuenta/concepto -------- */
    SELECT
        PR.Description AS processname,
        P.Description AS payrolltypename,
        AC.Code AS account,
        AC.Name AS accountname,
        C.Description AS conceptname,
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
                'Sin cuenta contable asociada en Configurar Conceptos'
            WHEN tiposhort = 'I' AND has_haber = 1 AND has_debe = 0 THEN
                'Ingreso configurado solo en HABER (falta cuenta DEBE)'
            WHEN tiposhort = 'D' AND has_debe = 1 AND has_haber = 0 THEN
                'Descuento configurado solo en DEBE (falta cuenta HABER)'
            WHEN tiposhort = 'A' AND has_debe = 0 AND has_haber = 0 THEN
                'Aporte sin cuentas DEBE/HABER'
            WHEN tiposhort = 'I' AND has_debe = 0 AND has_haber = 0 THEN
                'Ingreso sin cuentas DEBE/HABER'
            WHEN tiposhort = 'D' AND has_debe = 0 AND has_haber = 0 THEN
                'Descuento sin cuentas DEBE/HABER'
            ELSE
                'Configuración de cuentas incompleta'
        END AS problema,
        CASE
            /* Lado incorrecto: el monto aparece en el lado opuesto → afecta 2x la diferencia */
            WHEN tiposhort = 'I' AND has_haber = 1 AND has_debe = 0 THEN ROUND(2 * total_monto, 2)
            WHEN tiposhort = 'D' AND has_debe = 1 AND has_haber = 0 THEN ROUND(2 * total_monto, 2)
            /* Sin cuenta: el neto suele incluir el monto pero no hay contrapartida → 1x */
            WHEN sin_apd = 1 OR (has_debe = 0 AND has_haber = 0) THEN ROUND(ABS(total_monto), 2)
            ELSE ROUND(ABS(total_monto), 2)
        END AS impacto_estimado
    FROM agg
    WHERE
        /* Lado incorrecto: causa típica de diferencia 2x */
        (tiposhort = 'I' AND has_haber = 1 AND has_debe = 0)
        OR (tiposhort = 'D' AND has_debe = 1 AND has_haber = 0)
        /* Sin cuenta: ingresos/aportes (no descuentos componentes AFP) */
        OR (
            tiposhort IN ('I', 'A')
            AND (sin_apd = 1 OR (has_debe = 0 AND has_haber = 0))
        )
    ORDER BY impacto_estimado DESC, conceptname;
END
GO
