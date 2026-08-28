/*
    Genera líneas de detalle del archivo Scotiabank (140 caracteres por registro).
    No incluye cabecera (igual que el sistema PowerBuilder anterior).
    Requiere #ScotiabankPersonas (person) cargada por la app web.
    @par_responsible: referencia de pantalla (20 caracteres).
    Layout:
      1  tipo doc (código Scotiabank: DNI=1, CE=3, Pasaporte=4)
     12  código empleado (EmployeeCode; si vacío, DNI)
     60  nombre
      1  tipo cuenta (siempre 3)
     10  cuenta sueldo del trabajador
     20  CCI (siempre blanco)
     11  importe sin punto (ROUND*100)
      1  régimen (siempre 2)
      2  moneda (LO=00, EX=01)
     20  referencia / responsable
      2  constante 02
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_scotiabank_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @todos_bancos    CHAR(1) = 'N',
    @par_responsible VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';
    SET @par_responsible = LEFT(LTRIM(RTRIM(ISNULL(@par_responsible, ''))) + REPLICATE(' ', 20), 20);

    IF OBJECT_ID('tempdb..#ScotiabankPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #ScotiabankPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @collectionform VARCHAR(20);
    DECLARE @cod_moneda     CHAR(2);

    SELECT @collectionform = LTRIM(RTRIM(ISNULL(m.collectionform, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @collectionform = ''
    BEGIN
        RAISERROR('Configure la forma de pago (CollectionForm) en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SET @cod_moneda = CASE WHEN @par_currency = 'EX' THEN '01' ELSE '00' END;

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #ScotiabankPersonas tp
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
            INNER JOIN PR_Employee emp
                ON emp.person = epc.person
               AND emp.company = epc.company
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
          AND emp.collectionform = @collectionform
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
                ELSE LEFT(LTRIM(RTRIM(ISNULL(pdt.PDT, ''))) + ' ', 1)
            END AS tipo_doc_txt,
            LEFT(
                CASE
                    WHEN LTRIM(RTRIM(ISNULL(e.EmployeeCode, ''))) <> ''
                        THEN LTRIM(RTRIM(e.EmployeeCode))
                    WHEN LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ''))) <> ''
                        THEN LTRIM(RTRIM(sp.DocumentNumber))
                    ELSE LTRIM(RTRIM(ISNULL(sp.Ruc, '')))
                END + REPLICATE(' ', 12),
                12
            ) AS codigo_empleado,
            LEFT(
                LTRIM(RTRIM(
                    ISNULL(sp.lastname1, '') + ' ' +
                    ISNULL(sp.lastname2, '') + ' ' +
                    ISNULL(sp.name1, '') + ' ' +
                    ISNULL(sp.name2, '')
                )) + REPLICATE(' ', 60),
                60
            ) AS nombre_txt,
            LEFT(LTRIM(RTRIM(ISNULL(e.salaryaccount, ''))) + REPLICATE(' ', 10), 10) AS cuenta_txt,
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
            LEFT JOIN ERP_Bank eb
                ON eb.bank = e.salarybank
               AND eb.company = e.company
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND (
                e.salarycurrency = @par_currency
             OR (@par_currency = 'EX' AND ISNULL(e.socialassistancecenter, '') <> '')
          )
          AND e.collectionform = @collectionform
          AND LTRIM(RTRIM(ISNULL(e.salaryaccount, ''))) <> ''
          AND (
                (
                    @todos_bancos = 'N'
                    AND (
                        UPPER(ISNULL(eb.Name, '')) LIKE '%SCOTIABANK%'
                     OR UPPER(ISNULL(e.salarybank, '')) LIKE '%SCOTIABANK%'
                    )
                )
             OR (
                    @todos_bancos = 'Y'
                    AND (
                        (
                            UPPER(ISNULL(eb.Name, '')) LIKE '%SCOTIABANK%'
                         OR UPPER(ISNULL(e.salarybank, '')) LIKE '%SCOTIABANK%'
                        )
                     OR (
                            UPPER(ISNULL(eb.Name, '')) NOT LIKE '%SCOTIABANK%'
                            AND UPPER(ISNULL(e.salarybank, '')) NOT LIKE '%SCOTIABANK%'
                            AND (
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
        LEFT(
            tipo_doc_txt +
            codigo_empleado +
            nombre_txt +
            '3' +
            cuenta_txt +
            REPLICATE(' ', 20) +
            RIGHT(
                REPLICATE('0', 11) +
                CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
                11
            ) +
            '2' +
            @cod_moneda +
            @par_responsible +
            '02',
            140
        ) AS linea_txt
    FROM DetalleBase
    ORDER BY nombre_txt, person;
END
GO
