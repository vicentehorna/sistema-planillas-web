/*
    Archivo BANBIF depósito CTS — layout fijo 213 (validado vs
    AUXILIARES/SCOTIA/BanBif_CTS_LO20.txt del sistema anterior, mayo).

    Sin cabecera. Solo detalle 213 caracteres:
       7  secuencia (izquierda)
       1  tipo documento (DNI=1, CE=3, Pasaporte=4)
      11  documento
      20  apellido 1
      20  apellido 2
      40  nombres
      74  espacios
      14  cuenta CTS (prefijo C03 + número, igual BanBif_CTS_LO20)
      10  espacios
       1  moneda (1=soles, 2=dólares)
      15  importe en centavos

    Cuenta destino: 'C03' + PR_Employee.CTSAccount (si aún no trae C03).
    Importe: PR_Mapping.CTSConcept del proceso ShortName CTS.
    Requiere #BanbifCtsPersonas (person) cargada por la app.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_banbifcts_web]
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

    IF OBJECT_ID('tempdb..#BanbifCtsPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #BanbifCtsPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @banbifbank VARCHAR(20);
    DECLARE @tipo_moneda CHAR(1);

    SELECT @banbifbank = LTRIM(RTRIM(ISNULL(m.banbifbank, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @banbifbank IS NULL OR @banbifbank = ''
    BEGIN
        RAISERROR('Configure BanbifBank en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SET @tipo_moneda = CASE WHEN @par_currency = 'EX' THEN '2' ELSE '1' END;

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #BanbifCtsPersonas tp
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
            LTRIM(RTRIM(ISNULL(sp.lastname1, ''))) AS lastname1,
            LTRIM(RTRIM(ISNULL(sp.lastname2, ''))) AS lastname2,
            LTRIM(RTRIM(
                LTRIM(RTRIM(ISNULL(sp.name1, ''))) + ' ' +
                LTRIM(RTRIM(ISNULL(sp.name2, '')))
            )) AS nombres,
            REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', ''), CHAR(160), '') AS cuenta_raw,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND ISNULL(m.banbifbank, '') <> ''
          AND ISNULL(NULLIF(LTRIM(RTRIM(e.CTSCurrency)), ''), 'LO') = @par_currency
          AND REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))), '-', ''), ' ', ''), CHAR(160), '') <> ''
          AND (
                (@todos_bancos = 'N' AND e.CTSBank = m.banbifbank)
             OR (@todos_bancos = 'Y' AND ISNULL(e.CTSBank, '') <> '')
          )
    ),
    Numerado AS (
        SELECT
            *,
            LEFT(
                CASE
                    WHEN UPPER(LEFT(cuenta_raw, 3)) = 'C03' THEN cuenta_raw
                    ELSE 'C03' + cuenta_raw
                END + REPLICATE(' ', 14),
                14
            ) AS cuenta_fmt,
            ROW_NUMBER() OVER (
                ORDER BY lastname1, lastname2, nombres, person
            ) AS orden
        FROM DetalleBase
        WHERE cuenta_raw <> ''
    )
    SELECT
        orden,
        (
            LEFT(CAST(orden AS VARCHAR(10)) + REPLICATE(' ', 7), 7) +
            tipo_doc_txt +
            LEFT(documentnumber + REPLICATE(' ', 11), 11) +
            LEFT(lastname1 + REPLICATE(' ', 20), 20) +
            LEFT(lastname2 + REPLICATE(' ', 20), 20) +
            LEFT(nombres + REPLICATE(' ', 40), 40) +
            REPLICATE(' ', 74) +
            cuenta_fmt +
            REPLICATE(' ', 10) +
            @tipo_moneda +
            RIGHT(
                REPLICATE('0', 15) +
                CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
                15
            )
        ) AS linea_txt
    FROM Numerado
    ORDER BY orden;
END
GO
