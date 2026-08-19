/*
    PLAME Archivo 26 (.toc) — Trabajador otras condiciones (Estructura 26).

    Usado por: POST /api/plame/archivo-26/listado y generación TXT.

    Línea TXT: TipoDoc|NroDoc|AseguraPension|+Vida|FDSA-Ley29903|Domiciliado|
    Ejemplo:   01|00482388|0|1||1|

    Campos:
      1 Tipo documento (01, 04, 07, 09)
      2 Número documento
      3 Asegura tu pensión — derogado; siempre 0
      4 +Vida Seguro de Accidentes (1 aporta / 0 no; flagessaludvida)
      5 FDSA / retención Ley 29903 (vacío salvo tipo 56 o 98)
      6 Domiciliado (1 sí / 2 no; default 1)

    Solo tipos de documento Tabla 3: 01, 04, 07, 09 (carné extranjería 03 → 04).

    Parámetros:
      @cia    — compañía
      @period — periodo tributario YYYYMM (6 dígitos)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame26_web]
    @cia    VARCHAR(10),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    IF LEN(@period) > 6
        SET @period = LEFT(@period, 6);

    SELECT DISTINCT
        pr_employee.person,
        CASE
            WHEN sy_persondocumenttype.pdt = '03' THEN '04'
            ELSE LTRIM(RTRIM(sy_persondocumenttype.pdt))
        END AS documenttype,
        LTRIM(RTRIM(sy_person.documentnumber)) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(sy_person.lastname1, '') + ' ' +
            ISNULL(sy_person.lastname2, '') + ' ' +
            ISNULL(sy_person.name1, '') + ' ' +
            ISNULL(sy_person.name2, '')
        )) AS name,
        '0' AS pensionmembership,
        CASE WHEN pr_employee.flagessaludvida = 'Y' THEN '1' ELSE '0' END AS accidentinsurance,
        LTRIM(RTRIM(ISNULL(pr_employee.TypeAporte, ''))) AS typeaporte,
        LTRIM(RTRIM(ISNULL(sy_person.isdomiciled, ''))) AS isdomiciled,
        'N' AS selection
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK)
            ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        INNER JOIN pr_employeecategory (NOLOCK)
            ON pr_employee.employeecategory = pr_employeecategory.employeecategory
        INNER JOIN pr_mapping (NOLOCK)
            ON pr_mapping.company = @cia
        INNER JOIN pr_employeepayroll (NOLOCK)
            ON pr_employeepayroll.PayRollType = pr_employee.PayRollType
           AND pr_employeepayroll.Person = pr_employee.Person
           AND pr_employeepayroll.company = pr_employee.company
           AND pr_employeepayroll.ProcessType IN (pr_mapping.PlanillaProcess, pr_mapping.PlanillaSemProcess)
    WHERE pr_employee.company = @cia
      AND pr_employeecategory.PDT IN ('1')
      AND LEFT(pr_employeepayroll.PRPeriod, 6) = @period
      AND LTRIM(RTRIM(ISNULL(sy_person.documentnumber, ''))) <> ''
      AND (
            CHARINDEX(
                'SAINC',
                ISNULL((
                    SELECT TOP 1 LTRIM(RTRIM(Description))
                    FROM SY_Company
                    WHERE Company = @cia
                ), '')
            ) = 0
         OR EXISTS (
                SELECT 1
                FROM pr_payrolltype pt (NOLOCK)
                WHERE pt.PayRollType = pr_employeepayroll.PayRollType
                  AND pt.ShortName LIKE '%CIVIL%'
            )
      )
      AND (
            CASE
                WHEN sy_persondocumenttype.pdt = '03' THEN '04'
                ELSE LTRIM(RTRIM(sy_persondocumenttype.pdt))
            END
          ) IN ('01', '04', '07', '09')
    ORDER BY name;
END
GO
