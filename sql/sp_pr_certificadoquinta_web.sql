/*
    Certificado quinta — datos para PDF. Usado por preview_certificado_quinta.

    Parámetros:
      @cia              — compañía
      @payrolltype      — tipo de planilla
      @payrolltype_all  — 'Y' = todos los tipos de planilla
      @anio             — año calendario (ej. 2026)
      @person           — código persona
      @employee_all     — 'Y' = todos los empleados
      @activo           — 'Y' = solo empleados activos (filtro PB)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_certificadoquinta_web]
    @cia              VARCHAR(4),
    @payrolltype      VARCHAR(20),
    @payrolltype_all  CHAR(1) = 'N',
    @anio             VARCHAR(4),
    @person           VARCHAR(20),
    @employee_all     CHAR(1) = 'N',
    @activo           CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        P.Person AS person,
        P.Name AS nombre_persona,
        P.DocumentNumber AS docno_persona,
        P.Sex AS sexo,
        P.Address AS direccion_persona,
        ISNULL(O.Description, '') AS ocupacion,
        E.ceasedate AS fecha_cese,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.taxrentconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS monto_retenido,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.remtaxrentconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS remuneracion_bruta,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.taxrentconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS retencion_5ta_cat,

               ISNULL((
        SELECT
        SUM(EC.ConceptValue)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND (select top 1 Concept from PR_Concept where  FormulaCode = 'SUB_IMPUESTO') = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio and
                 ( right(PRPeriod,4) = '1212' or right(PRPeriod,4) = '1252'))
        ,0) AS sub_impuesto,

              ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
         M.utilitiesconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS utilidades,

        ISNULL((
            SELECT SUM(EC.ConceptValueLo)
            FROM PR_EmployeePayRollConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK)
                    ON C.Company = EC.Company AND C.Concept = EC.Concept
                INNER JOIN PR_ProcessType PT (NOLOCK)
                    ON PT.ProcessType = EC.ProcessType
            WHERE EC.Company = @cia
              AND EC.Person = P.Person
              AND EC.PayRollType = @payrolltype
              AND LEFT(LTRIM(RTRIM(EC.PRPeriod)), 4) = @anio
              AND ISNULL(C.flagafecto5ta, 'N') = 'Y'
              AND ISNULL(PT.ShortName, '') <> 'UTILIDADES'
        ), 0) AS importe_sueldos_asignaciones,

        ISNULL((
            SELECT SUM(EC.ConceptValueLo)
            FROM PR_EmployeePayRollConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK)
                    ON C.Company = EC.Company AND C.Concept = EC.Concept
                INNER JOIN PR_ProcessType PT (NOLOCK)
                    ON PT.ProcessType = EC.ProcessType
            WHERE EC.Company = @cia
              AND EC.Person = P.Person
              AND EC.PayRollType = @payrolltype
              AND LEFT(LTRIM(RTRIM(EC.PRPeriod)), 4) = @anio
              AND ISNULL(C.flagafecto5ta, 'N') = 'Y'
              AND ISNULL(PT.ShortName, '') = 'UTILIDADES'
        ), 0) AS importe_participacion_utilidades,

        ISNULL((
            SELECT SUM(ISNULL(EC.ConceptValueLo, EC.ConceptValue))
            FROM PR_EmployeeConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK)
                    ON C.Company = EC.Company AND C.Concept = EC.Concept
            WHERE EC.Company = @cia
              AND EC.Person = P.Person
              AND EC.PayRollType = @payrolltype
              AND C.FormulaCode = 'REM_ACUM_OTRA_EM'
              AND EC.FlagFrecuencyType = 'P'
              AND LEFT(LTRIM(RTRIM(EC.PRPeriodStart)), 4) = @anio
        ), 0) AS importe_remuneracion_otras_empresas,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.irembascomconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS rem_bas,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.icomisionconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS comision,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.irefund = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS reintegro,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.ibonifconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS bonificacion,

        dbo.F_PR_GetImportFormat(@cia, 'R', '1', P.Person, @anio) AS importe1,
        dbo.F_PR_GetImportFormat(@cia, 'R', '2', P.Person, @anio) AS importe2,
        dbo.F_PR_GetImportFormat(@cia, 'R', '3', P.Person, @anio) AS importe3,
        dbo.F_PR_GetImportFormat(@cia, 'R', '4', P.Person, @anio) AS importe4,
        dbo.F_PR_GetImportFormat(@cia, 'R', '14', P.Person, @anio) AS importe14,
        dbo.F_PR_GetImportFormat(@cia, 'R', '15', P.Person, @anio) AS importe15,
        dbo.F_PR_GetImportFormat(@cia, 'R', '16', P.Person, @anio) AS importe16,
        dbo.F_PR_GetImportFormat(@cia, 'R', '20', P.Person, @anio) AS importe20,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.ihe100concept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS extras100,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.ibonifprod = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS bonifproduc,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.irefund = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS reintegro_sueldo,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.ivacacconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS vacaciones,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.imovilconcept   = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS movil,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.foodvoucherincome = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS valealimento,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.ibonifcumpobj = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS bonifcumpobj,
        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_Mapping M (NOLOCK),
        PR_ProcessType PT (NOLOCK)
        WHERE
        EC.Company = @cia
        AND	M.Company = EC.Company
        AND EC.Person = P.Person
        AND PT.ProcessType = EC.ProcessType and
        (
         (PT.ShortName IN ('SEMANAL','VACACIONES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)= 'OBREROS'	)
         or  (PT.ShortName IN ('FIN_DE_MES') and (select ShortName from pr_payrolltype where payrolltype = EC.payrolltype)<> 'OBREROS')
        )
        AND M.otherincomeconcept = EC.Concept
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS otrosingresos,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'GRATIFICACION'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'GRATIFICACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS grati1,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'GRATI_TRUNCA'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS grati2,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'LEY_29714_BONIF_GRAT'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS grati3,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'TOTAL_REM_IMP_RENTA'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'FIN_DE_MES_TRASLADO'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS grati4,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'RET_5TA_CAT_LIQ'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS grati5,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'VAC_TRUNCAS'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS liqui1,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'LIQ_REINT_IMP_RENTA'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS liqui4,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'INDEMNIZACION_DESPID'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS liqui5,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'LEY_29714_PROPORCION'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS ley1,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'TOTAL_REM_IMP_RENTA'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'FIN_DE_MES'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS rem1,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'RET_5TA_CATEGORIA'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'FIN_DE_MES'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS ret1,

        ISNULL((
        SELECT
        top 1 SUM(EC.ConceptValue)
        FROM
        PR_EmployeeConcept EC (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'REM_ACUM_OTRA_EM'
        AND LEFT(EC.PRPeriodstart,4) = @anio
        )
        ,0) AS rem2,

        ISNULL((
        SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK),
        PR_ProcessType PT (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'TOTALINGRESO'
        AND PT.ProcessType = EC.ProcessType
        AND PT.ShortName = 'FIN_DE_MES'
        AND LEFT(EC.PRPeriod,4) = @anio
        )
        ,0) AS rem3,

        ISNULL((
        SELECT
        top 1 SUM(EC.ConceptValue)
        FROM
        PR_EmployeeConcept EC (NOLOCK),
        pr_concept C (nolock)
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        and EC.concept = C.concept
        and C.formulacode = 'RTA_5TA_OTRA_EMP'
        AND LEFT(EC.PRPeriodstart,4) = @anio
        )
        ,0) AS rem4,

            ISNULL((
               SELECT
        SUM(EC.ConceptValueLo)
        FROM
        PR_EmployeePayRollConcept EC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Company = EC.Company AND C.Concept = EC.Concept
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.Company = EC.Company AND PT.ProcessType = EC.ProcessType
        WHERE
        EC.Company = @cia
        AND EC.Person = P.Person
        AND C.FormulaCode = 'DEVOLUCION_QUINTA'
        AND PT.ShortName = 'LIQUIDACION'
        AND LEFT(EC.PRPeriod, 4) = @anio
                )
        ,0) AS devol_quinta,

        day(E.ceasedate) AS ceasedate_day_date,
        case month(E.ceasedate)
        when 1 then 'Enero'
        when 2 then 'Febrero'
        when 3 then 'Marzo'
        when 4 then 'Abril'
        when 5 then 'Mayo'
        when 6 then 'Junio'
        when 7 then 'Julio'
        when 8 then 'Agosto'
        when 9 then 'Septiembre'
        when 10 then 'Octubre'
        when 11 then 'Noviembre'
        when 12 then 'Diciembre'
        end AS ceasedate_month_date,
        case month(E.ceasedate)
        when 1 then 'Enero'
        when 2 then 'Febrero'
        when 3 then 'Marzo'
        when 4 then 'Abril'
        when 5 then 'Mayo'
        when 6 then 'Junio'
        when 7 then 'Julio'
        when 8 then 'Agosto'
        when 9 then 'Septiembre'
        when 10 then 'Octubre'
        when 11 then 'Noviembre'
        when 12 then 'Diciembre'
        end AS ceasedate_month_date2,
        year(E.ceasedate) AS ceasedate_year_date,

        ISNULL((
            SELECT TOP 1 ParameterNumberValue
            FROM PR_Parameter (NOLOCK)
            WHERE ShortName = 'UIT' + @anio AND Company = @cia
        ), 0) AS uit_valor,

        ISNULL((
            SELECT TOP 1 ParameterNumberValue * 7
            FROM PR_Parameter (NOLOCK)
            WHERE ShortName = 'UIT' + @anio AND Company = @cia
        ), 0) AS importe_deduccion_7uit,

        ISNULL((
            SELECT SUM(EC.ConceptValueLo)
            FROM PR_EmployeePayRollConcept EC (NOLOCK)
                INNER JOIN PR_Concept C (NOLOCK)
                    ON C.Company = EC.Company AND C.Concept = EC.Concept
            WHERE EC.Company = @cia
              AND EC.Person = P.Person
              AND EC.PayRollType = @payrolltype
              AND LEFT(LTRIM(RTRIM(EC.PRPeriod)), 4) = @anio
              AND C.FormulaCode = 'RET_5TA_CATEGORIA'
        ), 0) AS importe_impuesto_total_retenido,

        (select ParameterNumberValue * 7 from PR_Parameter where shortname = 'UIT' + @anio and PR_Parameter.Company = E.Company) AS deducciones_5ta_cat,
        case when isnull((select TOP 1 IsNull(ParameterNumberValue,0)  from PR_Parameter where shortname = 'PRREP_UIT'+convert(char(4),@anio) and PR_Parameter.Company = E.Company),0) = 0 then
              (select TOP 1 IsNull(ParameterNumberValue,0)  from PR_Parameter where shortname = 'PRREP_UIT' and PR_Parameter.Company = E.Company) else
        (select TOP 1 IsNull(ParameterNumberValue,0)  from PR_Parameter where shortname = 'PRREP_UIT'+convert(char(4),@anio) and PR_Parameter.Company = E.Company) end AS uit,
              (select TOP 1 IsNull(ParameterNumberValue,0)  from PR_Parameter where shortname = 'PRREP_FACTOR_UIT' and PR_Parameter.Company = E.Company) AS factor_uit,
        (SELECT C.Representative FROM SY_Company C (NOLOCK) WHERE C.Company = @cia) AS representante,
        (SELECT C.Rep_Position FROM SY_Company C (NOLOCK) WHERE C.Company = @cia) AS rep_cargo,

        (SELECT PDT.Description FROM SY_Company C (NOLOCK), SY_PersonDocumentType PDT (NOLOCK) WHERE C.Company = @cia AND PDT.PersonDocumentType = C.Rep_DocType ) AS representante_doctipo,
        (SELECT C.Rep_DocNumber FROM SY_Company C (NOLOCK) WHERE C.Company = @cia) AS representante_docno,
        (SELECT C.description FROM SY_Company C (NOLOCK) WHERE C.Company = @cia) AS compania_nombre,
        (SELECT C.address FROM SY_Company C (NOLOCK) WHERE C.Company = @cia) AS compania_direccion,
        (SELECT C.RUC FROM SY_Company C (NOLOCK) WHERE C.Company = @cia) AS compania_ruc,
        (select description from sy_replicationunit where replicationunit = P.replicationunit) AS unidad,

        (select Description from sy_persondocumenttype where PersonDocumentType = P.employeedocumenttype) AS tipodocumento
        FROM
        SY_Person P (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK) ON P.Person = E.Person
        LEFT JOIN PR_Position O (NOLOCK) ON E.Position = O.Position
        LEFT JOIN PR_PensionType PT (NOLOCK) ON E.PensionType = PT.PensionType
        LEFT JOIN PR_SCTR S (NOLOCK) ON S.SCTR = E.SCTRPension
        WHERE
                E.Company = @cia
                AND ((@payrolltype_all = 'Y') OR (E.PayRollType = @payrolltype))
                AND ((@employee_all = 'Y') OR (P.Person = @person))
                AND (@activo = 'N' OR (P.status = 'A' AND E.flagparticipar = 'Y' AND CASE WHEN E.status IS NULL THEN 'N' WHEN E.status = '' THEN 'N' WHEN E.status = 'N' THEN 'N' ELSE 'Y' END = 'N'))
            ORDER BY nombre_persona
END
GO
