/*
    Formato de Utilidades (RPR044) — cabecera y detalle de conceptos por trabajador.

    Reemplaza en web la tabla temporal tmp_prrep01 de PowerBuilder: los conceptos
    se leen directamente de PR_EmployeePayRollConcept sin tabla intermedia.

    Resultset 1 — Cabecera (dw principal RPR044).
    Resultset 2 — Líneas de cálculo ordenadas por ConceptOrder (dw_pr_r044_1).

    Rangos ConceptOrder usados en el reporte PB:
      1-4   : Utilidades por distribuir
      5-6   : 2.1 Según días laborados (inicio)
      7-9   : 2.2 Según remuneraciones percibidas
      10-13 : Monto de participación a percibir

    Parámetros:
      @cia, @payrolltype, @processtype, @period, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_formatoutilidades_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    /* --- Resultset 1: cabecera --- */
    SELECT
        LTRIM(RTRIM(
            ISNULL(SP.LastName1, '') + ' '
            + ISNULL(SP.LastName2, '') + ' '
            + ISNULL(SP.Name1, '') + ' '
            + ISNULL(SP.Name2, '')
        )) AS person_name,
        SP.DocumentNumber AS person_document,
        EPR.Person AS person,
        EPR.Company AS company,
        EPR.ProcessType AS processtype,
        EPR.PayRollType AS payrolltype,
        EPR.PRPeriod AS prperiod,
        SC.Description AS company_name,
        SC.Ruc AS company_ruc,
        SC.Address AS company_address,
        SC.Representative AS representative,
        PT.Description AS process_description,
        ISNULL(EPC_NET.ConceptValueLo, EPC_NET.ConceptValue) AS net_value,
        SC.Rep_Position AS rep_position,
        M.defaultduedate AS fecha_pago,
        SC.Rep_DocNumber AS rep_docnumber,
        CAST(LEFT(@period, 4) AS INT) - 1 AS ejercicio,
        CASE
            WHEN UPPER(ISNULL(SC.Description, '')) LIKE '%EL CLAN%'
                THEN M.defaultduedate
            ELSE CAST(GETDATE() AS DATE)
        END AS fecha_pago_display
    FROM PR_Mapping M (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Company = M.Company
        INNER JOIN SY_Person SP (NOLOCK)
            ON E.Person = SP.Person
        INNER JOIN SY_Company SC (NOLOCK)
            ON E.Company = SC.Company
        INNER JOIN PR_EmployeePayRoll EPR (NOLOCK)
            ON EPR.Company = E.Company
           AND EPR.Person = E.Person
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON EPR.ProcessType = PT.ProcessType
           AND EPR.Company = PT.Company
        INNER JOIN PR_Period PER (NOLOCK)
            ON PER.PayRollType = @payrolltype
           AND PER.PRPeriod = @period
        INNER JOIN PR_EmployeePayRollConcept EPC_NET (NOLOCK)
            ON EPC_NET.Company = @cia
           AND EPC_NET.PayRollType = @payrolltype
           AND EPC_NET.Person = EPR.Person
           AND EPC_NET.ProcessType = @processtype
           AND EPC_NET.PRPeriod = @period
           AND EPC_NET.Concept = M.utilitiesconcept
    WHERE M.Company = @cia
      AND EPR.Company = @cia
      AND EPR.PayRollType = @payrolltype
      AND EPR.ProcessType = @processtype
      AND EPR.PRPeriod = @period
      AND EPR.Person = @person;

    /* --- Resultset 2: detalle (equivale a tmp_prrep01 por persona) --- */
    SELECT
        C.Person AS person,
        CT.ShortName AS concept_type_shortname,
        CN.PrintText AS print_text,
        ISNULL(C.ConceptValueLo, C.ConceptValue) AS concept_value,
        CN.ConceptOrder AS concept_order
    FROM PR_EmployeePayRollConcept C (NOLOCK)
        INNER JOIN PR_Concept CN (NOLOCK)
            ON C.Concept = CN.Concept
           AND C.Company = CN.Company
        INNER JOIN PR_ConceptType CT (NOLOCK)
            ON CN.ConceptType = CT.ConceptType
    WHERE C.Company = @cia
      AND C.ProcessType = @processtype
      AND C.PayRollType = @payrolltype
      AND C.PRPeriod = @period
      AND C.Person = @person
    ORDER BY CN.ConceptOrder ASC, CN.PrintText ASC;
END
GO
