/*
    Reporte detallado de trabajadores (migración DW PB9 SP_PR_reporteListaTrabajadores).
    Usado por: POST /api/reportes/lista-trabajadores (reporte_trabajadores.html).

    Filtros web (fase 1):
      @cia                 — compañía (obligatorio)
      @payrolltype         — tipo planilla; '0' = todos
      @nombre              — texto libre (busca en apellidos + nombres)
      @docnro              — nro. documento (LIKE)
      @fecha_ingreso_all   — Y = sin filtro fecha; N = rango
      @fecha_ingreso_desde / @fecha_ingreso_hasta — YYYY-MM-DD
      @activos             — Y = solo activos (Status='N'), N = solo inactivos
      @cesados             — T=todos, Y=con cese, N=sin cese

    Fecha ingreso efectiva: ISNULL(ReEntryDate, EntryDate).
    Dirección: SY_Person.Address.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportelistatrabajadores_web]
    @cia                  VARCHAR(4),
    @payrolltype          VARCHAR(20)  = '0',
    @nombre               VARCHAR(100) = '',
    @docnro               VARCHAR(20)  = '',
    @fecha_ingreso_all    CHAR(1)      = 'Y',
    @fecha_ingreso_desde  VARCHAR(10)  = '',
    @fecha_ingreso_hasta  VARCHAR(10)  = '',
    @activos              CHAR(1)      = 'Y',
    @cesados              CHAR(1)      = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '0')));
    IF @payrolltype = '' SET @payrolltype = '0';
    SET @nombre = LTRIM(RTRIM(ISNULL(@nombre, '')));
    SET @docnro = LTRIM(RTRIM(ISNULL(@docnro, '')));
    SET @fecha_ingreso_all = UPPER(LTRIM(RTRIM(ISNULL(@fecha_ingreso_all, 'Y'))));
    IF @fecha_ingreso_all NOT IN ('Y', 'N') SET @fecha_ingreso_all = 'Y';
    SET @fecha_ingreso_desde = LTRIM(RTRIM(ISNULL(@fecha_ingreso_desde, '')));
    SET @fecha_ingreso_hasta = LTRIM(RTRIM(ISNULL(@fecha_ingreso_hasta, '')));
    SET @activos = UPPER(LTRIM(RTRIM(ISNULL(@activos, 'Y'))));
    IF @activos NOT IN ('Y', 'N') SET @activos = 'Y';
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    IF @fecha_ingreso_desde <> '' AND ISDATE(@fecha_ingreso_desde) = 1
        SET @fd = CONVERT(DATE, @fecha_ingreso_desde, 120);
    IF @fecha_ingreso_hasta <> '' AND ISDATE(@fecha_ingreso_hasta) = 1
        SET @fh = CONVERT(DATE, @fecha_ingreso_hasta, 120);

    SELECT
        ISNULL(pt.Description, '') AS tipo_planilla,
        ISNULL(NULLIF(LTRIM(RTRIM(e.EmployeeCode)), ''), e.Person) AS codigo_persona,
        LTRIM(RTRIM(
            ISNULL(p.LastName1, '') + ' ' +
            ISNULL(p.LastName2, '') + ' ' +
            ISNULL(p.Name1, '') + ' ' +
            ISNULL(p.Name2, '')
        )) AS nombre_completo,
        LTRIM(RTRIM(ISNULL(p.LastName1, ''))) AS apellido_paterno,
        LTRIM(RTRIM(ISNULL(p.LastName2, ''))) AS apellido_materno,
        LTRIM(RTRIM(ISNULL(p.Name1, ''))) AS nombre1,
        LTRIM(RTRIM(ISNULL(p.Name2, ''))) AS nombre2,
        ISNULL(dt.Description, '') AS tipo_documento,
        ISNULL(p.DocumentNumber, '') AS numero_documento,
        ISNULL(p.Telephone, '') AS telefono,
        ISNULL(p.EMail, '') AS mail,
        CASE LTRIM(RTRIM(ISNULL(p.Sex, '')))
            WHEN '2' THEN 'Femenino'
            WHEN '1' THEN 'Masculino'
            ELSE ''
        END AS sexo,
        CONVERT(varchar(10), p.BirthDate, 23) AS fecha_nacimiento,
        CONVERT(varchar(10), e.EntryDate, 23) AS fecha_ingreso,
        CONVERT(varchar(10), e.ReEntryDate, 23) AS fecha_reingreso,
        CONVERT(varchar(10), e.CeaseDate, 23) AS fecha_cese,
        ISNULL(cr.Description, '') AS motivo_cese,
        CASE
            WHEN LTRIM(RTRIM(ISNULL(e.Status, ''))) IN ('', 'N') THEN 'NO'
            ELSE 'SI'
        END AS inactivo,
        ISNULL(cc.CCCode, ISNULL(e.CostCenter, '')) AS centro_costo_codigo,
        ISNULL(cc.Name, ISNULL(e.CostCenterName, '')) AS nombre_centro_costo,
        ISNULL(pen.Description, '') AS regimen_pension,
        ISNULL(afp.Description, '') AS afp,
        ISNULL(e.AFPCard, '') AS cuspp,
        ISNULL(b1.Name, '') AS banco_remuneracion,
        CASE
            WHEN LTRIM(RTRIM(ISNULL(e.SalaryCurrency, ''))) = 'EX' THEN 'EXTRANJERA'
            ELSE 'LOCAL'
        END AS moneda_remuneracion,
        ISNULL(at.Description, '') AS tipo_cuenta_remuneracion,
        ISNULL(e.SalaryAccount, '') AS cuenta_remuneracion,
        ISNULL(b2.Name, '') AS banco_cts,
        CASE
            WHEN LTRIM(RTRIM(ISNULL(e.CTSCurrency, ''))) = 'EX' THEN 'EXTRANJERA'
            ELSE 'LOCAL'
        END AS moneda_cts,
        ISNULL(e.CTSAccount, '') AS cuenta_cts,
        ISNULL(cat.Description, '') AS categoria,
        ISNULL(et.Description, '') AS tipo_trabajador,
        ISNULL(es.Description, '') AS situacion_trabajador,
        ISNULL(ap.Description, '') AS perfil_contable,
        ISNULL(pos.Description, ISNULL(e.POSITION_DESC, '')) AS cargo,
        ISNULL(pc.Description, '') AS categoria_ocupacional,
        ISNULL(cf.Name, '') AS tipo_pago,
        ISNULL(cm.Description, '') AS tipocontrato,
        ISNULL(p.Address, '') AS direccion,
        ISNULL(p.SecTelephone, '') AS celular,
        ISNULL(ss.Description, '') AS situacion,
        (
            SELECT TOP 1 ec.ConceptValue
            FROM PR_EmployeeConcept ec (NOLOCK)
            INNER JOIN PR_Concept c (NOLOCK)
                ON c.Concept = ec.Concept
               AND c.FormulaCode = 'REM_BASICA'
            WHERE ec.Person = e.Person
              AND ec.FlagFrecuencyType = 'P'
              AND ec.PRPeriodStart = (
                    SELECT MAX(ec2.PRPeriodStart)
                    FROM PR_EmployeeConcept ec2 (NOLOCK)
                    INNER JOIN PR_Concept c2 (NOLOCK)
                        ON c2.Concept = ec2.Concept
                       AND c2.FormulaCode = 'REM_BASICA'
                    WHERE ec2.Person = e.Person
                      AND ec2.FlagFrecuencyType = 'P'
              )
        ) AS sueldo,
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(e.FlagAsigFamiliar, 'N')))) = 'Y' THEN 'SI'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept ec (NOLOCK)
                INNER JOIN PR_Concept c (NOLOCK)
                    ON c.Concept = ec.Concept
                   AND c.FormulaCode = 'FLAG_ASIG_FAM'
                WHERE ec.Person = e.Person
                  AND ec.FlagFrecuencyType = 'P'
            ) THEN 'SI'
            ELSE 'NO'
        END AS familiar,
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(e.FlagMixta, 'N')))) = 'Y' THEN 'SI'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept ec (NOLOCK)
                INNER JOIN PR_Concept c (NOLOCK)
                    ON c.Concept = ec.Concept
                   AND c.FormulaCode = 'AFP_FLUJO'
                WHERE ec.Person = e.Person
                  AND ec.FlagFrecuencyType = 'P'
            ) THEN 'SI'
            ELSE 'NO'
        END AS mixta,
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(e.FlagEssaludVida, 'N')))) = 'Y' THEN 'Si'
            ELSE 'No'
        END AS flagessaludvida
    FROM PR_Employee e (NOLOCK)
    INNER JOIN SY_Person p (NOLOCK)
        ON p.Person = e.Person
    LEFT JOIN PR_PayRollType pt (NOLOCK)
        ON pt.PayRollType = e.PayRollType
       AND pt.Company = e.Company
    LEFT JOIN SY_PersonDocumentType dt (NOLOCK)
        ON dt.PersonDocumentType = p.EmployeeDocumentType
    LEFT JOIN PR_CeaseReason cr (NOLOCK)
        ON cr.CeaseReason = e.CeaseReason
    LEFT JOIN AC_CostCenter cc (NOLOCK)
        ON cc.CostCenter = e.CostCenter
    LEFT JOIN PR_PensionType pen (NOLOCK)
        ON pen.PensionType = e.PensionType
    LEFT JOIN PR_AFP afp (NOLOCK)
        ON afp.AFP = e.AFP
    LEFT JOIN ERP_Bank b1 (NOLOCK)
        ON b1.Bank = e.SalaryBank
    LEFT JOIN ERP_Bank b2 (NOLOCK)
        ON b2.Bank = e.CTSBank
    LEFT JOIN TE_AccountType at (NOLOCK)
        ON at.AccountType = e.SalaryAccountType
    LEFT JOIN PR_EmployeeCategory cat (NOLOCK)
        ON cat.EmployeeCategory = e.EmployeeCategory
    LEFT JOIN PR_EmployeeType et (NOLOCK)
        ON et.EmployeeType = e.EmployeeType
    LEFT JOIN PR_EmployeeStatus es (NOLOCK)
        ON es.EmployeeStatus = e.EmployeeStatus
    LEFT JOIN PR_AccountProfile ap (NOLOCK)
        ON ap.AccountProfile = e.AccountProfile
    LEFT JOIN PR_Position pos (NOLOCK)
        ON pos.Position = e.Position
    LEFT JOIN PR_ProfessionalCategory pc (NOLOCK)
        ON pc.ProfessionalCategory = e.ProfessionalCategory
    LEFT JOIN TE_CollectionForm cf (NOLOCK)
        ON cf.CollectionForm = e.CollectionForm
    LEFT JOIN HR_ContractModality cm (NOLOCK)
        ON cm.ContractModality = e.ContractModality
    LEFT JOIN PR_SpecialStatus ss (NOLOCK)
        ON ss.SpecialStatus = e.SpecialStatus
    WHERE e.Company = @cia
      AND (
            @payrolltype = '0'
         OR e.PayRollType = @payrolltype
         OR e.PayRollType IN (
                SELECT pt2.PayRollType
                FROM PR_PayRollType pt2 (NOLOCK)
                WHERE pt2.Company = @cia
                  AND (
                        pt2.Description = @payrolltype
                     OR pt2.ShortName = @payrolltype
                  )
            )
          )
      AND (
            @nombre = ''
         OR LTRIM(RTRIM(
                ISNULL(p.LastName1, '') + ' ' +
                ISNULL(p.LastName2, '') + ' ' +
                ISNULL(p.Name1, '') + ' ' +
                ISNULL(p.Name2, '')
            )) LIKE '%' + @nombre + '%'
         OR ISNULL(p.Name, '') LIKE '%' + @nombre + '%'
          )
      AND (@docnro = '' OR p.DocumentNumber LIKE '%' + @docnro + '%')
      AND (
            (@activos = 'Y' AND LTRIM(RTRIM(ISNULL(e.Status, ''))) IN ('', 'N'))
         OR (@activos = 'N' AND LTRIM(RTRIM(ISNULL(e.Status, ''))) NOT IN ('', 'N'))
          )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
          )
      AND (
            @fecha_ingreso_all = 'Y'
         OR (
                ISNULL(e.ReEntryDate, e.EntryDate) IS NOT NULL
            AND (@fd IS NULL
                 OR CAST(ISNULL(e.ReEntryDate, e.EntryDate) AS DATE) >= @fd)
            AND (@fh IS NULL
                 OR CAST(ISNULL(e.ReEntryDate, e.EntryDate) AS DATE) <= @fh)
            )
          )
    ORDER BY nombre_completo, codigo_persona;
END
GO
