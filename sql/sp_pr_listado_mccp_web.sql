/*
    MEF — Interface MCCP (Módulo de Control de Planillas del Sector Público).
    Listado de detalle para el archivo plano PLL<entidad><YYYYMM><TT><SUB><REGIMEN>.TXT

    Usado por: POST /api/mef/interface-mccp/listado y generación del TXT MCCP.

    Solo proceso MENSUAL: PR_Mapping.PlanillaProcess (FIN_DE_MES) de la compañía.

    Parámetros:
      @cia         — compañía
      @period      — periodo YYYYMM (6 dígitos)
      @payroll_all — Y = todas las planillas, N = filtrar por @payroll
      @payroll     — tipo de planilla (cuando @payroll_all = N)

    Devuelve una fila por trabajador + concepto (ConceptType I/D/A, monetario,
    de boleta), con la clase MCCP (1=Ingreso, 2=Descuento, 3=Aporte patronal),
    un código de concepto MEF preliminar y el correlativo de cargo/plaza
    (últimos 6 dígitos de PR_Employee.Position).

    Código MEF preliminar (fase presentación; luego será configurable):
      ESSALUD -> 0007, AFP aporte 10% (PDT 0608) -> 0009,
      AFP seguro (0606) -> 0010, AFP comisión (0601) -> 0008,
      ONP (0607) -> 0002, resto: PDT del concepto o 0000 si no tiene.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_mccp_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';

    SELECT
        A.Person                                              AS person,
        CASE WHEN S.pdt = '03' THEN '04' ELSE S.pdt END       AS documenttype,
        LTRIM(RTRIM(B.documentnumber))                        AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(B.lastname1, '') + ' ' +
            ISNULL(B.lastname2, '') + ' ' +
            ISNULL(B.name1, '') + ' ' +
            ISNULL(B.name2, '')
        ))                                                    AS name,
        A.clase                                               AS clase,
        A.codigo_mef                                          AS codigo_mef,
        A.descripcion                                         AS descripcion,
        A.formulacode                                         AS formulacode,
        A.pdt                                                 AS pdt,
        CAST(A.monto AS DECIMAL(19, 2))                       AS monto,
        RIGHT('000000' + (
            SELECT ISNULL(MAX(RIGHT(LTRIM(RTRIM(ISNULL(E2.Position, ''))), 6)), '')
            FROM PR_Employee E2
            WHERE E2.Company = @cia AND E2.Person = A.Person
        ), 6)                                                 AS cargo,
        'N'                                                   AS selection
    FROM (
        SELECT
            epc.Person AS Person,
            CASE LTRIM(RTRIM(ct.ShortName))
                WHEN 'I' THEN '1'
                WHEN 'D' THEN '2'
                WHEN 'A' THEN '3'
            END AS clase,
            CASE
                WHEN LTRIM(RTRIM(UPPER(ISNULL(c.FormulaCode, '')))) LIKE 'ESSALUD%' THEN '0007'
                WHEN LTRIM(RTRIM(ISNULL(c.PDT, ''))) = '0608' THEN '0009'
                WHEN LTRIM(RTRIM(ISNULL(c.PDT, ''))) = '0606' THEN '0010'
                WHEN LTRIM(RTRIM(ISNULL(c.PDT, ''))) = '0601' THEN '0008'
                WHEN LTRIM(RTRIM(ISNULL(c.PDT, ''))) = '0607' THEN '0002'
                WHEN LTRIM(RTRIM(ISNULL(c.PDT, ''))) <> '' THEN LTRIM(RTRIM(c.PDT))
                ELSE '0000'
            END AS codigo_mef,
            UPPER(LTRIM(RTRIM(ISNULL(c.Description, '')))) AS descripcion,
            LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) AS formulacode,
            LTRIM(RTRIM(ISNULL(c.PDT, ''))) AS pdt,
            SUM(epc.ConceptValueLo) AS monto
        FROM PR_EmployeePayrollConcept epc (NOLOCK)
            INNER JOIN PR_Concept c (NOLOCK)
                ON c.Concept = epc.Concept
            INNER JOIN PR_ConceptType ct (NOLOCK)
                ON ct.ConceptType = c.ConceptType
            INNER JOIN PR_Mapping m (NOLOCK)
                ON m.Company = epc.Company
        WHERE epc.Company = @cia
          AND LEFT(epc.PRPeriod, 6) = @period
          AND epc.ProcessType = m.PlanillaProcess
          AND (@payroll_all = 'Y' OR epc.PayRollType = @payroll)
          AND epc.ConceptValueLo IS NOT NULL
          AND LTRIM(RTRIM(ct.ShortName)) IN ('I', 'D', 'A')
          AND c.FlagIsMonetary = 'Y'
          AND c.FlagPayrollTicket = 'Y'
        GROUP BY
            epc.Person,
            ct.ShortName,
            c.FormulaCode,
            c.PDT,
            c.Description
        HAVING SUM(epc.ConceptValueLo) <> 0
    ) A
        INNER JOIN PR_Employee E ON E.Person = A.Person AND E.Company = @cia
        INNER JOIN SY_Person B ON B.Person = A.Person
        LEFT JOIN sy_persondocumenttype S ON S.persondocumenttype = B.employeedocumenttype
    ORDER BY name ASC, A.clase ASC, A.codigo_mef ASC, A.descripcion ASC;
END
GO
