/*
    Consolidado de Provisiones (CTS + Gratificación + Vacaciones), todas las empresas.
    Usado por: POST /reporte_consolidado_provisiones (reporte_consolidado_provisiones.html).
    Referencia legacy: sp_pr_reporteconsolidado_provisiones (hm_alamo).

    Devuelve filas largas (empresa × trabajador × proceso × concepto); la matriz
    (una fila por empresa + trabajador, conceptos en columnas) se arma en la web.

    @payroll_desc     — PR_PayRollType.Description (igual en todas las empresas)
    @period           — PRPeriod (yyyymmdd)
    @person           — '0' = todos
    @salarybank_name  — ERP_Bank.Name; '' = todos
    @repunit          — SY_Person.ReplicationUnit; '0' = todas
    @fecha_ingreso_*  — Y = todas; N = rango sobre ISNULL(ReEntryDate, EntryDate)
    @userid           — NULL = sin filtro; '' = ninguna; valor = SY_UserCompany
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteconsolidado_provisiones_web]
    @payroll_desc         VARCHAR(200),
    @period               VARCHAR(8),
    @person               VARCHAR(20)  = '0',
    @salarybank_name      VARCHAR(200) = '',
    @repunit              VARCHAR(20)  = '0',
    @fecha_ingreso_all    CHAR(1)      = 'Y',
    @fecha_ingreso_desde  VARCHAR(10)  = '',
    @fecha_ingreso_hasta  VARCHAR(10)  = '',
    @userid               VARCHAR(30)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @payroll_desc = LTRIM(RTRIM(ISNULL(@payroll_desc, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    SET @salarybank_name = LTRIM(RTRIM(ISNULL(@salarybank_name, '')));
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';
    SET @fecha_ingreso_all = UPPER(LTRIM(RTRIM(ISNULL(@fecha_ingreso_all, 'Y'))));
    IF @fecha_ingreso_all NOT IN ('Y', 'N') SET @fecha_ingreso_all = 'Y';

    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;
    IF ISNULL(@fecha_ingreso_desde, '') <> '' AND ISDATE(@fecha_ingreso_desde) = 1
        SET @fd = CONVERT(DATE, @fecha_ingreso_desde, 120);
    IF ISNULL(@fecha_ingreso_hasta, '') <> '' AND ISDATE(@fecha_ingreso_hasta) = 1
        SET @fh = CONVERT(DATE, @fecha_ingreso_hasta, 120);

    DECLARE @filtra BIT = CASE WHEN @userid IS NULL THEN 0 ELSE 1 END;
    DECLARE @uid VARCHAR(30) = LTRIM(RTRIM(ISNULL(@userid, '')));

    CREATE TABLE #epc (
        Company     VARCHAR(4)    COLLATE DATABASE_DEFAULT NOT NULL,
        Person      VARCHAR(20)   COLLATE DATABASE_DEFAULT NOT NULL,
        PayRollType VARCHAR(20)   COLLATE DATABASE_DEFAULT NOT NULL,
        ProcessType VARCHAR(20)   COLLATE DATABASE_DEFAULT NOT NULL,
        proceso     VARCHAR(30)   COLLATE DATABASE_DEFAULT NOT NULL,
        formulacode VARCHAR(50)   COLLATE DATABASE_DEFAULT NOT NULL,
        printtext   VARCHAR(200)  COLLATE DATABASE_DEFAULT NULL,
        reporden    INT           NULL,
        valor       NUMERIC(19, 2) NULL
    );

    INSERT INTO #epc (Company, Person, PayRollType, ProcessType, proceso, formulacode, printtext, reporden, valor)
    SELECT
        epc.Company,
        epc.Person,
        epc.PayRollType,
        epc.ProcessType,
        LTRIM(RTRIM(pt.ShortName)),
        LTRIM(RTRIM(c.FormulaCode)),
        MAX(LTRIM(RTRIM(ISNULL(NULLIF(c.PrintText, ''), c.Description)))),
        MIN(ISNULL(c.reporden, 0)),
        SUM(ROUND(epc.ConceptValue, 2))
    FROM PR_EmployeePayRollConcept epc (NOLOCK)
        INNER JOIN SY_Company sc (NOLOCK)
            ON sc.Company = epc.Company
           AND sc.status = 'A'
        INNER JOIN PR_PayRollType prt (NOLOCK)
            ON prt.Company = epc.Company
           AND prt.PayRollType = epc.PayRollType
        INNER JOIN PR_ProcessType pt (NOLOCK)
            ON pt.Company = epc.Company
           AND pt.ProcessType = epc.ProcessType
        INNER JOIN PR_Concept c (NOLOCK)
            ON c.Company = epc.Company
           AND c.Concept = epc.Concept
        INNER JOIN PR_ConceptType t (NOLOCK)
            ON t.ConceptType = c.ConceptType
    WHERE epc.PRPeriod = @period
      AND LTRIM(RTRIM(prt.Description)) = @payroll_desc
      AND pt.ShortName IN ('PROVISION_CTS', 'PROVISION_GRATIF', 'PROVISION_VACACIONES')
      AND ISNULL(c.reporden, 0) <> 0
      AND t.ShortName IN ('I', 'D', 'A', 'T', 'G', 'X')
      AND ISNULL(c.FormulaCode, '') <> 'ASIG_FAM_ESPOSA'
      AND (@person = '0' OR epc.Person = @person)
      AND (
            @filtra = 0
         OR (
                @uid <> ''
            AND EXISTS (
                    SELECT 1
                    FROM SY_UserCompany uc (NOLOCK)
                    WHERE LTRIM(RTRIM(uc.UserID)) = @uid
                      AND LTRIM(RTRIM(uc.idcompany)) = LTRIM(RTRIM(epc.Company))
                )
            )
          )
    GROUP BY epc.Company, epc.Person, epc.PayRollType, epc.ProcessType,
             LTRIM(RTRIM(pt.ShortName)), LTRIM(RTRIM(c.FormulaCode));

    SELECT
        x.Company                          AS company,
        LTRIM(RTRIM(sc.Description))       AS empresa,
        x.Person                           AS person,
        sp.Name                            AS name,
        ISNULL(e.ReEntryDate, e.EntryDate) AS entrydate,
        ep.ceasedate                       AS ceasedate,
        (SELECT TOP 1 pos.Description FROM PR_Position pos (NOLOCK)
          WHERE pos.Position = ep.position) AS position,
        CASE
            WHEN LTRIM(RTRIM(ISNULL(pens.PDT, ''))) = '99'
                 OR LTRIM(RTRIM(ISNULL(e.PensionType, ''))) = '' THEN 'SIN REGIMEN'
            WHEN LTRIM(RTRIM(ISNULL(pens.PDT, ''))) = '02' THEN 'ONP'
            WHEN LTRIM(RTRIM(ISNULL(pens.PDT, ''))) IN ('21', '22', '23', '24', '25') THEN
                ISNULL((SELECT TOP 1 a.Description FROM PR_AFP a (NOLOCK)
                         WHERE a.AFP = ISNULL(NULLIF(LTRIM(RTRIM(ep.AFP)), ''), e.AFP)),
                       ISNULL(pens.Description, 'SIN REGIMEN'))
            ELSE ISNULL((SELECT TOP 1 a.Description FROM PR_AFP a (NOLOCK) WHERE a.AFP = ep.AFP), 'SIN REGIMEN')
        END                                AS afp,
        (SELECT TOP 1 cc.Description FROM AC_CostCenter cc (NOLOCK)
          WHERE cc.CostCenter = ep.costcenter) AS ccname,
        (SELECT TOP 1 cc.CCCode FROM AC_CostCenter cc (NOLOCK)
          WHERE cc.CostCenter = ep.costcenter) AS costcenter,
        ru.Description                     AS unidad,
        CASE WHEN ISNULL(sp.isrecruiter, 'N') = 'Y' THEN 'H' ELSE 'P' END AS tipopago,
        (SELECT TOP 1 ap.Description FROM PR_AccountProfile ap (NOLOCK)
          WHERE ap.AccountProfile = e.AccountProfile AND ap.Company = x.Company) AS profile,
        (SELECT SUM(rh.hourday) FROM PR_REGISTERHOUR rh (NOLOCK)
          WHERE rh.period = @period AND rh.Company = x.Company AND rh.person = x.Person) AS horas,
        bk.Name                            AS banco,
        e.SalaryAccount                    AS numcuenta,
        x.proceso,
        x.formulacode,
        x.printtext,
        x.reporden,
        x.valor
    FROM #epc x
        INNER JOIN SY_Company sc (NOLOCK)
            ON sc.Company = x.Company
        INNER JOIN PR_Employee e (NOLOCK)
            ON e.Company = x.Company
           AND e.Person = x.Person
        INNER JOIN SY_Person sp (NOLOCK)
            ON sp.Person = x.Person
        OUTER APPLY (
            SELECT TOP 1 epr.ceasedate, epr.position, epr.AFP, epr.costcenter
            FROM PR_EmployeePayRoll epr (NOLOCK)
            WHERE epr.Company = x.Company
              AND epr.Person = x.Person
              AND epr.PayRollType = x.PayRollType
              AND epr.PRPeriod = @period
              AND epr.ProcessType IN (
                    SELECT p2.ProcessType FROM PR_ProcessType p2 (NOLOCK)
                    WHERE p2.Company = x.Company
                      AND p2.ShortName IN ('PROVISION_CTS', 'PROVISION_GRATIF', 'PROVISION_VACACIONES'))
            ORDER BY epr.ProcessType
        ) ep
        LEFT JOIN PR_PensionType pens (NOLOCK)
            ON pens.PensionType = e.PensionType
           AND (LTRIM(RTRIM(ISNULL(pens.Company, ''))) = '' OR LTRIM(RTRIM(pens.Company)) = e.Company)
        LEFT JOIN SY_ReplicationUnit ru (NOLOCK)
            ON ru.ReplicationUnit = sp.ReplicationUnit
        LEFT JOIN ERP_Bank bk (NOLOCK)
            ON bk.Bank = e.SalaryBank
           AND bk.Company = x.Company
    WHERE (@salarybank_name = '' OR LTRIM(RTRIM(ISNULL(bk.Name, ''))) = @salarybank_name)
      AND (@repunit = '0' OR sp.ReplicationUnit = @repunit)
      AND (
            @fecha_ingreso_all = 'Y'
         OR (
                ISNULL(e.ReEntryDate, e.EntryDate) IS NOT NULL
            AND (@fd IS NULL OR CAST(ISNULL(e.ReEntryDate, e.EntryDate) AS DATE) >= @fd)
            AND (@fh IS NULL OR CAST(ISNULL(e.ReEntryDate, e.EntryDate) AS DATE) <= @fh)
            )
          )
    ORDER BY empresa, sp.Name, x.Person, x.reporden, x.proceso;

    DROP TABLE #epc;
END
GO
