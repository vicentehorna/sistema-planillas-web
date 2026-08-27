/*
    Datos para generar contrato Word/PDF (marcadores Jinja / docxtpl).
    Usado por: POST /api/contratos/generar

    Params: @cia, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generarcontrato_datos_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    ;WITH contrato_activo AS (
        SELECT TOP 1
            pc.Person,
            pc.Company,
            pc.startdate,
            pc.enddate,
            pc.Status,
            pc.Contractno
        FROM PR_PersonContract pc (NOLOCK)
        WHERE pc.Company = @cia
          AND pc.Person = @person
          AND LTRIM(RTRIM(ISNULL(pc.Status, ''))) = 'A'
          AND (pc.enddate IS NULL OR CONVERT(date, pc.enddate) >= CONVERT(date, GETDATE()))
        ORDER BY pc.startdate DESC, pc.Contractno DESC
    ),
    contrato_anterior AS (
        SELECT TOP 1
            pc.Person,
            pc.Company,
            pc.startdate,
            pc.enddate,
            pc.Contractno
        FROM PR_PersonContract pc (NOLOCK)
        INNER JOIN contrato_activo ca
            ON ca.Person = pc.Person
           AND ca.Company = pc.Company
        WHERE pc.Company = @cia
          AND pc.Person = @person
          AND (
              pc.startdate < ca.startdate
              OR (pc.startdate = ca.startdate AND pc.Contractno < ca.Contractno)
          )
        ORDER BY pc.startdate DESC, pc.Contractno DESC
    )
    SELECT
        e.Person AS person,
        e.Company AS company,
        ISNULL(NULLIF(LTRIM(RTRIM(e.EmployeeCode)), ''), e.Person) AS codigo,
        LTRIM(RTRIM(ISNULL(sc.Description, ''))) AS empresa,
        LTRIM(RTRIM(ISNULL(sc.Ruc, ''))) AS ruc,
        LTRIM(RTRIM(ISNULL(sc.Address, ''))) AS domicilio_empresa,
        LTRIM(RTRIM(ISNULL(sc.Representative, ''))) AS representante,
        LTRIM(RTRIM(ISNULL(sc.Rep_Position, ''))) AS cargo_representante,
        LTRIM(RTRIM(
            ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(dt_rep.Description, ''))), ''), '') +
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(sc.Rep_DocNumber, ''))), '') IS NULL THEN ''
                ELSE ' N° ' + LTRIM(RTRIM(sc.Rep_DocNumber))
            END
        )) AS doc_representante,
        LTRIM(RTRIM(
            ISNULL(p.LastName1, '') + ' ' +
            ISNULL(p.LastName2, '') + ' ' +
            ISNULL(p.Name1, '') + ' ' +
            ISNULL(p.Name2, '')
        )) AS trabajador,
        LTRIM(RTRIM(ISNULL(p.LastName1, ''))) AS apellido_paterno,
        LTRIM(RTRIM(ISNULL(p.LastName2, ''))) AS apellido_materno,
        LTRIM(RTRIM(
            ISNULL(p.Name1, '') +
            CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(p.Name2, ''))), '') IS NULL THEN '' ELSE ' ' + LTRIM(RTRIM(p.Name2)) END
        )) AS nombres,
        LTRIM(RTRIM(ISNULL(dt.Description, 'DNI'))) AS tipo_documento,
        LTRIM(RTRIM(ISNULL(p.DocumentNumber, e.Person))) AS dni,
        LTRIM(RTRIM(ISNULL(p.Address, ''))) AS direccion,
        LTRIM(RTRIM(ISNULL(loc.Name, ''))) AS distrito,
        LTRIM(RTRIM(ISNULL(prov.Name, ''))) AS provincia,
        LTRIM(RTRIM(ISNULL(depto.Name, ''))) AS departamento,
        LTRIM(RTRIM(ISNULL(loc.pdt, ''))) AS ubigeo,
        CAST('' AS VARCHAR(100)) AS nacionalidad,
        CASE
            WHEN LTRIM(RTRIM(ISNULL(p.Sex, ''))) = '1' THEN 'Masculino'
            WHEN LTRIM(RTRIM(ISNULL(p.Sex, ''))) = '2' THEN 'Femenino'
            ELSE LTRIM(RTRIM(ISNULL(p.Sex, '')))
        END AS sexo,
        LTRIM(RTRIM(ISNULL(pos.Description, ISNULL(pos.Name, '')))) AS cargo,
        LTRIM(RTRIM(ISNULL(e.CostCenterName, ISNULL(e.CostCenter, '')))) AS centro_costo,
        LTRIM(RTRIM(ISNULL(cm.Description, ''))) AS modalidad,
        CONVERT(decimal(18, 2), COALESCE(
            e.rembasica,
            (
                SELECT TOP 1 ec.ConceptValue
                FROM PR_EmployeeConcept ec (NOLOCK)
                INNER JOIN PR_Concept c (NOLOCK)
                    ON c.Concept = ec.Concept
                   AND c.Company = ec.Company
                WHERE ec.Company = e.Company
                  AND ec.Person = e.Person
                  AND c.FormulaCode = 'REM_BASICA'
                  AND ec.FlagFrecuencyType = 'P'
                  AND ec.PRPeriodEnd IS NULL
            ),
            e.salary,
            0
        )) AS sueldo,
        CONVERT(varchar(10), ISNULL(e.ReEntryDate, e.EntryDate), 23) AS fecha_ingreso,
        CONVERT(varchar(10), ISNULL(ca.startdate, ISNULL(e.ReEntryDate, e.EntryDate)), 23) AS inicio_contrato,
        CONVERT(varchar(10), ca.enddate, 23) AS fin_contrato,
        CONVERT(varchar(10), cp.startdate, 23) AS inicio_contrato_anterior,
        CONVERT(varchar(10), cp.enddate, 23) AS fin_contrato_anterior,
        DAY(ISNULL(ca.startdate, ISNULL(e.ReEntryDate, e.EntryDate))) AS inicio_dia,
        CASE MONTH(ISNULL(ca.startdate, ISNULL(e.ReEntryDate, e.EntryDate)))
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
            ELSE ''
        END AS inicio_mes,
        YEAR(ISNULL(ca.startdate, ISNULL(e.ReEntryDate, e.EntryDate))) AS inicio_anio,
        DAY(ca.enddate) AS fin_dia,
        CASE MONTH(ca.enddate)
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
            ELSE NULL
        END AS fin_mes,
        YEAR(ca.enddate) AS fin_anio,
        DAY(GETDATE()) AS dia_firma,
        CASE MONTH(GETDATE())
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS mes_firma,
        YEAR(GETDATE()) AS anio_firma,
        CONVERT(varchar(10), GETDATE(), 23) AS fecha_firma,
        LTRIM(RTRIM(ISNULL(ru.Description, ISNULL(ru.Name, ISNULL(p.ReplicationUnit, 'Lima'))))) AS ciudad
    FROM PR_Employee e (NOLOCK)
    INNER JOIN SY_Person p (NOLOCK)
        ON p.Person = e.Person
    LEFT JOIN SY_Company sc (NOLOCK)
        ON sc.Company = e.Company
    LEFT JOIN SY_PersonDocumentType dt (NOLOCK)
        ON dt.PersonDocumentType = p.EmployeeDocumentType
       AND (dt.Company = e.Company OR dt.Company IS NULL)
    LEFT JOIN SY_PersonDocumentType dt_rep (NOLOCK)
        ON dt_rep.PersonDocumentType = sc.Rep_DocType
    LEFT JOIN PR_Position pos (NOLOCK)
        ON pos.Position = e.Position
       AND (pos.Company = e.Company OR pos.Company IS NULL)
    LEFT JOIN HR_ContractModality cm (NOLOCK)
        ON cm.ContractModality = e.ContractModality
       AND cm.Company = e.Company
    LEFT JOIN SY_ReplicationUnit ru (NOLOCK)
        ON ru.ReplicationUnit = p.ReplicationUnit
    LEFT JOIN SY_Localite loc (NOLOCK)
        ON loc.Localite = p.Localite
    LEFT JOIN SY_Province prov (NOLOCK)
        ON prov.Province = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(p.Province, ''))), ''), loc.Province)
    LEFT JOIN SY_Department depto (NOLOCK)
        ON depto.Department = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(p.Department, ''))), ''), prov.Department)
    LEFT JOIN contrato_activo ca
        ON ca.Person = e.Person
       AND ca.Company = e.Company
    LEFT JOIN contrato_anterior cp
        ON cp.Person = e.Person
       AND cp.Company = e.Company
    WHERE e.Company = @cia
      AND e.Person = @person;
END
GO
