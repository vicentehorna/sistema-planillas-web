/*
    Control de Pagos AFP — resumen por tipo de planilla y AFP.
    Legacy PowerBuilder: PAGOS AFP (RPR001).

    Usado por: GET /afp/control-pagos, POST /reporte_control_pagos_afp

    Parámetros:
      @company    — código de compañía
      @payrolltype — tipo de planilla; vacío / NULL / TODOS = todas
      @period     — periodo YYYYMM (6 dígitos)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_control_pagos_afp_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    IF UPPER(@payrolltype) IN ('TODOS', 'TODAS', 'T', '0')
        SET @payrolltype = '';

    /*
        Cuando se consultan todas las planillas, la descripción queda vacía y
        el GROUP BY consolida EMPLEADOS + CONSTRUCCIÓN (u otras) por AFP.
    */
    SELECT
        CASE WHEN @payrolltype = '' THEN '' ELSE MAX(P.description) END AS tipoplanilla,
        A.description AS afpname,
        COUNT(*) AS cantidad,
        SUM(ROUND(F.fixedamountlo, 2)) AS fixedamountlo,
        SUM(ROUND(F.insuredamountlo, 2)) AS insuredamountlo,
        SUM(ROUND(F.employercontributionlo, 2)) AS employercontributionlo,
        SUM(ROUND(F.variableamountlo, 2)) AS variableamountlo,
        SUM(ROUND(F.arcomisionamountlo, 2)) AS arcomisionamountlo
    FROM PR_EmployeeAFPHeader H (NOLOCK)
        INNER JOIN PR_EmployeeAFP F (NOLOCK)
            ON H.company = F.company
           AND H.replicationunit = F.replicationunit
           AND H.costcenter = F.costcenter
           AND H.prperiod = F.prperiod
           AND H.afp = F.afp
           AND H.payrolltype = F.payrolltype
        INNER JOIN PR_Employee E (NOLOCK)
            ON F.company = E.company
           AND F.person = E.person
        INNER JOIN PR_AFP A (NOLOCK)
            ON F.afp = A.afp
        INNER JOIN PR_PayRollType P (NOLOCK)
            ON E.payrolltype = P.payrolltype
    WHERE H.company = @company
      AND (@payrolltype = '' OR H.payrolltype = @payrolltype)
      AND LEFT(H.prperiod, 6) = @period
      /* Mismo criterio que el listado AFPnet: la planilla del periodo debe tener AFP. */
      AND EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll EP (NOLOCK)
                INNER JOIN PR_ProcessType PT (NOLOCK)
                    ON PT.ProcessType = EP.ProcessType
                   AND PT.Company = EP.Company
            WHERE EP.Company = F.company
              AND EP.Person = F.person
              AND LEFT(EP.PRPeriod, 6) = @period
              AND ISNULL(LTRIM(RTRIM(EP.AFP)), '') <> ''
              AND LTRIM(RTRIM(PT.ShortName)) IN ('FIN_DE_MES', 'LIQUIDACION', 'SEMANAL')
              AND (@payrolltype = '' OR EP.PayRollType = @payrolltype)
      )
    GROUP BY
        CASE WHEN @payrolltype = '' THEN '' ELSE P.description END,
        A.description
    ORDER BY
        CASE WHEN @payrolltype = '' THEN '' ELSE P.description END,
        A.description;
END
GO
