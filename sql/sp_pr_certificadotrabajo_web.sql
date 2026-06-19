/*
    Certificado de Trabajo — datos del documento (dw PowerBuilder r058).

    Filtro de planilla: PROCESSTYPE = LIQUIDACION (liquidación del periodo).

    Parámetros:
      @cia         — compañía
      @payrolltype — tipo de planilla
      @period      — periodo PRPeriod
      @person      — código trabajador
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_certificadotrabajo_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sc.Description AS company_name,
        sc.Ruc AS company_ruc,
        sc.Address AS company_address,
        sc.Telephone AS company_telephone,
        sc.Rep_Position AS rep_position,
        sp.Name AS person_name,
        ISNULL(dt.Description, 'Sin Tipo de Documento') AS person_document_type,
        sp.DocumentNumber AS person_document,
        DAY(pc.StartDate) AS contract_start_day,
        CASE MONTH(pc.StartDate)
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS contract_start_month,
        YEAR(pc.StartDate) AS contract_start_year,
        DAY(pc.EndDate) AS contract_end_day,
        CASE MONTH(pc.EndDate)
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS contract_end_month,
        YEAR(pc.EndDate) AS contract_end_year,
        ISNULL(pp.Description, 'Sin Cargo Asignado') AS person_position,
        sc.Representative AS representative,
        RTRIM(ISNULL(dt2.Description, '')) + ' N°' + ISNULL(sc.Rep_DocNumber, '') AS company_representative_numdoc,
        DAY(GETDATE()) AS day_print,
        CASE MONTH(GETDATE())
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS month_print,
        YEAR(GETDATE()) AS year_print,
        DAY(pe.CeaseDate) AS ceasedate_day,
        CASE MONTH(pe.CeaseDate)
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS ceasedate_month,
        YEAR(pe.CeaseDate) AS ceasedate_year,
        DAY(ISNULL(pe.ReEntryDate, pe.EntryDate)) AS fecha_entry_day,
        CASE MONTH(ISNULL(pe.ReEntryDate, pe.EntryDate))
            WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
            WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
            WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
            WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
        END AS fecha_entry_month,
        YEAR(ISNULL(pe.ReEntryDate, pe.EntryDate)) AS fecha_entry_year,
        sp.LastName1 AS lastname1,
        sp.Sex AS sex,
        cc.Description AS centrocosto
    FROM PR_Employee pe
        INNER JOIN SY_Person sp ON pe.Person = sp.Person
        LEFT JOIN PR_Position pp ON pe.Position = pp.Position
        INNER JOIN SY_Company sc ON pe.Company = sc.Company
        LEFT JOIN PR_PersonContract pc
            ON pe.Company = pc.Company
           AND pe.Person = pc.Person
           AND pc.Status = 'A'
        INNER JOIN PR_EmployeePayRoll epc ON pe.Person = epc.Person
        INNER JOIN PR_ProcessType pt_liq (NOLOCK)
            ON epc.ProcessType = pt_liq.ProcessType
           AND epc.Company = pt_liq.Company
        LEFT JOIN SY_PersonDocumentType dt ON sp.DocumentType = dt.PersonDocumentType
        LEFT JOIN SY_PersonDocumentType dt2 ON sc.Rep_DocType = dt2.PersonDocumentType
        LEFT JOIN AC_CostCenter cc ON pe.CostCenter = cc.CostCenter
    WHERE pe.Company = @cia
      AND epc.Company = @cia
      AND epc.PayRollType = @payrolltype
      AND pt_liq.ShortName = 'LIQUIDACION'
      AND epc.PRPeriod = @period
      AND epc.Person = @person;
END
GO
